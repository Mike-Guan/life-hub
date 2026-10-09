import SwiftUI

// KURO-12 (UI 审核 2026-10-08): she borrowed HAKU's headphone nod, blinked on his metronome and slept
// through her desk time. Her own small moves now come from a seeded pool, 8-20 s apart, on her own stream.
/// A small move KURO makes now and then while idle.
enum KuroIdle: CaseIterable, Sendable {
    /// Her cat ears flick up twice.
    case ears
    /// The stylus taps the tablet twice.
    case stylus
    /// She looks up from the tablet and back down.
    case lookUp
    /// The drink comes up and she blows on it.
    case blow
    /// She looks off to the side and back.
    case aside
    /// The racket bobs twice in her hand.
    case racket
    /// The ponytail swishes and settles.
    case ponytail
    /// A finger pushes the glasses up; they catch the light.
    case glasses
    /// The red pen taps the notebooks twice.
    case pen

    /// KURO's idle stream; HAKU has his own, so the two never blink together.
    static let seed: UInt64 = 0x4B55

    /// How long the move lasts, in seconds.
    var length: TimeInterval {
        switch self {
        case .ears: 0.6
        case .stylus, .pen, .racket, .ponytail, .glasses: 1
        case .lookUp, .aside: 1.4
        case .blow: 1.6
        }
    }

    /// The moves `look` draws from.
    static func pool(_ look: KuroLook) -> [KuroIdle] {
        switch look {
        case .work: [.ears, .stylus, .lookUp]
        case .chill: [.ears, .blow, .aside]
        case .tennis: [.ears, .racket, .ponytail]
        case .desk: [.ears, .glasses, .pen]
        }
    }

    /// The move playing in `look` at idle time `t` and how far into it she is (0..<1), or nil between moves.
    static func at(_ t: TimeInterval, look: KuroLook) -> (KuroIdle, Double)? {
        let pool = pool(look)
        guard let beat = IdleClock.beat(at: t, lengths: pool.map(\.length), seed: seed) else { return nil }
        let move = pool[beat.kind]
        return (move, beat.phase / move.length)
    }

    /// The parts shown or hidden at `progress` (0..<1) into the move.
    func apply(_ p: Double, to visible: inout Set<KuroPart>) {
        switch self {
        case .blow:
            if (0.3..<0.8).contains(p) {
                visible.subtract([.mouthCat, .mouthFlat])
                visible.formUnion([.mouthO, .tapPuff])
            }
        case .glasses:
            if p < 0.5 {
                visible.remove(.deskPen)
                visible.insert(.tapFinger)
            } else if p < 0.8 {
                visible.insert(.tapGlint)
            }
        default:
            break
        }
    }

    /// How far `part` moves at `progress` (0..<1) into the move, in SVG units.
    func shift(_ part: KuroPart, progress p: Double) -> CGSize {
        // Two quick bumps over the move.
        let twice = CGFloat(abs(sin(p * 2 * .pi)))
        let held = CGFloat(Self.hold(p))
        switch self {
        case .ears where part == .catEars: return CGSize(width: 0, height: -3.5 * twice)
        case .stylus where part == .workStylus: return CGSize(width: 0, height: 5 * twice)
        case .pen where part == .deskPen: return CGSize(width: 0, height: 5 * twice)
        case .racket where part == .tennisRacket: return CGSize(width: 0, height: -6 * twice)
        case .lookUp where Self.eyes.contains(part): return CGSize(width: 0, height: -3 * held)
        case .aside where Self.eyes.contains(part): return CGSize(width: 3 * held, height: 0)
        case .blow where part == .chillCup: return CGSize(width: 0, height: -6 * held)
        case .glasses where part == .deskGlasses:
            return CGSize(width: 0, height: -2 * CGFloat(Self.hold(p, from: 0.25)))
        case .ponytail where part == .tennisPonytail:
            return CGSize(width: 3 * CGFloat(sin(p * 4 * .pi) * (1 - p)), height: 0)
        default: return .zero
        }
    }

    /// The parts that are her eyes.
    private static let eyes: Set<KuroPart> = [
        .eyesOpen, .eyesClosed, .eyesDrowsy, .eyesBright, .eyesDown, .eyesHappy, .eyesSurprised, .eyesLow,
    ]

    /// 0 → 1 eased in from `from`, held, eased back to 0 over the last fifth.
    private static func hold(_ p: Double, from start: Double = 0) -> Double {
        let up = (p - start) / 0.2
        let down = (1 - p) / 0.2
        let x = min(max(min(up, down), 0), 1)
        return x * x * (3 - 2 * x)
    }
}

/// Idle time that keeps running from where it was when her energy changes her pace.
struct IdlePace: Equatable {
    var time: TimeInterval
    var phase: TimeInterval
    var pace: Double

    /// The idle time at `t`.
    func phase(at t: TimeInterval) -> TimeInterval {
        phase + (t - time) * pace
    }

    /// The same idle time from `t` on, running at `pace`.
    func changing(to pace: Double, at t: TimeInterval) -> IdlePace {
        IdlePace(time: t, phase: phase(at: t), pace: pace)
    }
}

extension KuroPose {
    /// The same pose `progress` (0..<1) into the idle `move`.
    func idling(_ move: (KuroIdle, Double)?) -> KuroPose {
        var pose = self
        pose.idle = move?.0
        pose.idleProgress = move?.1 ?? 0
        return pose
    }
}
