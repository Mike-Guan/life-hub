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
    /// The drink comes up to her lips, she blows on it and puts it down.
    case blow
    /// She looks off to the side and back.
    case aside
    /// The racket bobs twice in her hand.
    case racket
    /// The ponytail swishes and settles.
    case ponytail
    // Tennis is her main card (Mike 10/14, 第 1 批身份卡 第 3 轮).
    /// Tennis: the racket goes flat and the ball bounces on it three times, high then lower, and she catches it.
    case juggle
    /// Tennis: the racket spins one turn in her hand, then a small toss and catch.
    case twirl
    /// The glasses nudge up and catch the light.
    case glasses
    /// The red pen taps the notebooks twice.
    case pen
    // Identity cards, batch 1 (第 1 批身份卡 预览).
    /// Boxing: the gloves tap together twice, her eyes shut on each tap.
    case gloves
    /// Fitness: the yoga block goes down to her lap and she stays there, only blinking and breathing.
    case lap
    /// Study: the highlighter runs across a line and she looks pleased.
    case highlight
    /// Art: two strokes, the pen held up to judge the distance, a tilt of the head, then back to drawing.
    case draw

    /// KURO's idle stream; HAKU has his own, so the two never blink together.
    static let seed: UInt64 = 0x4B55

    /// How long the move lasts, in seconds.
    var length: TimeInterval {
        switch self {
        case .ears: 0.6
        case .stylus, .pen, .racket, .ponytail, .glasses: 1
        case .lookUp, .aside: 1.4
        case .blow, .draw: 2
        case .gloves: 1.2
        case .highlight: 1.6
        case .juggle: 3
        case .twirl: 2
        case .lap: 6
        }
    }

    /// The moves `look` draws from.
    static func pool(_ look: KuroLook) -> [KuroIdle] {
        switch look {
        case .work: [.ears, .stylus, .lookUp]
        case .chill: [.ears, .blow, .aside]
        case .tennis: [.ears, .racket, .ponytail, .juggle, .twirl]
        case .desk: [.ears, .glasses, .pen]
        // Boxing is an ordinary card for her (Mike 10/14): only the gloves tapping together.
        case .box: [.ears, .gloves, .ponytail]
        case .fitness: [.ears, .ponytail, .lap]
        case .study: [.ears, .aside, .highlight]
        case .art: [.ears, .draw]
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
            // The same cup and puff as her sip tap (UI 审核 2026-10-09: the puff must leave the lips).
            guard p < 0.9 else { return }
            visible.subtract([.chillCup, .itemBlanket])
            visible.insert(.tapCup)
            if (0.3..<0.65).contains(p) {
                visible.subtract([.mouthCat, .mouthFlat])
                visible.formUnion([.mouthO, .tapPuff])
            }
        case .glasses:
            // No hand: a finger with no arm read as floating (UI 审核 2026-10-09).
            if (0.5..<0.8).contains(p) { visible.insert(.tapGlint) }
        case .juggle:
            // The flat racket is her own one; with the gold racket from the shop she just holds it.
            guard visible.contains(.tennisRacket), p < 0.97 else { return }
            visible.remove(.tennisRacket)
            visible.formUnion([.juggleRacket, .tapBall])
            if Self.ballHeight(p) > 30 { Self.swapEyes(&visible, to: .eyesBright) }
            if p >= 0.88 {
                Self.swapEyes(&visible, to: .eyesHappy)
                visible.insert(.tapSparkle)
            }
        case .twirl:
            if (0.8..<0.97).contains(p) { Self.swapEyes(&visible, to: .eyesHappy) }
        case .gloves:
            if Self.tapping(p) { Self.eyesShut(&visible) }
        case .lap:
            if (0.55..<0.65).contains(p) { Self.eyesShut(&visible) }
        case .highlight:
            if (0.35..<0.95).contains(p) { visible.insert(.studyMark) }
            if (0.6..<0.85).contains(p) { Self.swapEyes(&visible, to: .eyesHappy) }
        case .draw:
            if (0.45..<0.75).contains(p) { Self.swapEyes(&visible, to: .eyesDown) }
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
        case .blow where part == .tapCup:
            let lift = CGFloat(Self.hold(p, rise: 0.2, fall: 0.2, end: 0.9))
            return CGSize(width: 26 * (1 - lift), height: 36 * (1 - lift))
        case .glasses where part == .deskGlasses:
            return CGSize(width: 0, height: -2 * CGFloat(Self.hold(p, from: 0.25)))
        case .ponytail where part == .tennisPonytail:
            return CGSize(width: 3 * CGFloat(sin(p * 4 * .pi) * (1 - p)), height: 0)
        // The ball sits on the flat racket face at (106, 93); tapBall is drawn at (103, 92).
        case .juggle where part == .tapBall: return CGSize(width: 3, height: 1 - Self.ballHeight(p))
        // Her eyes follow the ball up.
        case .juggle where Self.eyes.contains(part):
            return CGSize(width: 0, height: -3 * Self.ballHeight(p) / 45)
        // The toss at the end lifts the racket along its handle.
        case .twirl where part == .tennisRacket:
            let toss = Self.hold(p, from: 0.75, rise: 0.1, fall: 0.1, end: 0.98)
            return CGSize(width: 2 * toss, height: -5.6 * toss)
        case .gloves where part == .boxGloveL: return CGSize(width: 4 * Self.together(p), height: 0)
        case .gloves where part == .boxGloveR: return CGSize(width: -4 * Self.together(p), height: 0)
        case .lap where part == .gymBlock:
            return CGSize(width: 0, height: 14 * CGFloat(Self.hold(p, rise: 0.08, fall: 0.08)))
        case .highlight where part == .studyHighlighter:
            // Back to the start of the line, then across it.
            return CGSize(width: -12 * CGFloat(Self.hold(p, rise: 0.2, fall: 0.3, end: 0.5)), height: 0)
        case .draw where part == .craftPen:
            let up = CGFloat(Self.hold(p, from: 0.35, rise: 0.1, fall: 0.15, end: 0.85))
            return CGSize(width: -3 * twice * (1 - up), height: -14 * up)
        default: return .zero
        }
    }

    /// How high the juggled ball is above the racket at `p`, in SVG units: three bounces, each lower.
    static func ballHeight(_ p: Double) -> CGFloat {
        let bounces: [(start: Double, end: Double, peak: Double)] = [
            (0.05, 0.45, 45), (0.45, 0.7, 22), (0.7, 0.88, 14),
        ]
        guard let bounce = bounces.first(where: { ($0.start..<$0.end).contains(p) }) else { return 0 }
        return CGFloat(bounce.peak * sin((p - bounce.start) / (bounce.end - bounce.start) * .pi))
    }

    /// How close the gloves are (0...1) at `p`: they meet twice over the move.
    static func together(_ p: Double) -> CGFloat {
        CGFloat(max(0, sin(p * 4 * .pi)))
    }

    /// Whether the gloves are touching at `p`.
    private static func tapping(_ p: Double) -> Bool { together(p) > 0.85 }

    private static func eyesShut(_ visible: inout Set<KuroPart>) { swapEyes(&visible, to: .eyesClosed) }

    /// Replaces whichever eyes are showing with `eyes`.
    private static func swapEyes(_ visible: inout Set<KuroPart>, to eyes: KuroPart) {
        guard !visible.isDisjoint(with: Self.eyes) else { return }
        visible.subtract(Self.eyes)
        visible.insert(eyes)
    }

    /// The parts that are her eyes.
    private static let eyes: Set<KuroPart> = [
        .eyesOpen, .eyesClosed, .eyesDrowsy, .eyesBright, .eyesDown, .eyesHappy, .eyesSurprised, .eyesLow, .eyesFull,
    ]

    /// 0 → 1 eased in over `rise` from `start`, held, eased back to 0 over `fall` before `end`.
    private static func hold(
        _ p: Double, from start: Double = 0, rise: Double = 0.2, fall: Double = 0.2, end: Double = 1
    ) -> Double {
        let up = (p - start) / rise
        let down = (end - p) / fall
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
