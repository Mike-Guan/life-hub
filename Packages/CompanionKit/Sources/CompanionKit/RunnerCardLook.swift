import HubCore
import SwiftUI

// Drawn like the approved preview 第1批 身份卡 (haku-1-底衣, haku-4-身份卡).
/// What HAKU wears for an identity card other than boxing.
enum RunnerCardLook: CaseIterable, Sendable {
    /// Sport base, a visor, a racket in the right hand and a ball.
    case tennis
    /// Sport base, the gym bag on the floor by the door and a small dumbbell in the right hand.
    case fitness
    /// Out base and an open book in both hands.
    case study
    /// Craft base, a sketchbook and a pencil.
    case art
    /// Sport base and a small speaker on the floor.
    case dance
    /// Out base and a ukulele leaning in the corner.
    case music
    /// Sport base and ski goggles on the forehead.
    case ski

    // The only place the card-to-look mapping lives, like `KuroLook(mode:card:)`.
    /// The look for `card`, or nil for boxing and for cards without a look yet, which keep the boxing kit.
    init?(card: IdentityKind?) {
        switch card {
        case .tennis: self = .tennis
        case .fitness: self = .fitness
        case .study: self = .study
        case .art: self = .art
        case .dance: self = .dance
        case .music: self = .music
        case .ski: self = .ski
        default: return nil
        }
    }

    /// Whether this look wears the sport base: the dark jacket with the orange stripe.
    var sporty: Bool { self == .tennis || self == .fitness || self == .dance || self == .ski }

    /// Every part of the look, figure included.
    var parts: Set<RunnerPart> {
        var parts = RunnerFigure.baseParts.union([.maskDown, .earringNeon])
        // The approved art look draws no mouth.
        if self != .art { parts.insert(.mouthSmile) }
        if sporty {
            parts.remove(.stripeNeon)
            parts.insert(.stripeSport)
        }
        switch self {
        case .tennis: parts.formUnion([.eyesChill, .tennisVisor, .tennisRacket, .racketHand, .tennisBall])
        case .fitness: parts.formUnion([.eyesChill, .handWeight])
        case .study: parts.formUnion([.eyesWork, .book, .bookPage])
        case .art: parts.formUnion([.eyesWork, .lidsWork, .browsWork, .apron, .sketchbook, .pencil])
        case .dance: parts.formUnion([.eyesChill, .wristbandHand, .danceSpeaker])
        case .music: parts.formUnion([.eyesWork, .ukulele])
        case .ski: parts.formUnion([.eyesChill, .wristbandHand, .skiGoggles])
        }
        return parts
    }

    /// What the look holds in its hands.
    var held: Set<RunnerPart> {
        switch self {
        case .tennis: [.tennisRacket, .racketHand, .tennisBall]
        case .fitness: [.handWeight]
        case .study: [.book, .bookPage]
        case .art: [.sketchbook, .pencil]
        case .dance, .music, .ski: []
        }
    }

    // The fist with the wristband is the right hand, so it goes too when the hand holds something else.
    /// What the look puts aside while HAKU does something else: what it holds, what it wears over the base and
    /// what stands in the corner.
    var props: Set<RunnerPart> {
        held.union([.tennisVisor, .apron, .wristbandHand, .danceSpeaker, .ukulele, .skiGoggles])
    }

    /// The jacket fill: dark for sport, the green off-work jacket for out and craft.
    var jacket: Color { sporty ? RunnerPalette.jacket : RunnerPalette.jacketChill }
}

extension RunnerPose {
    /// The same pose dressed for `card`, which only the identity card mode wears.
    /// - Parameters:
    ///   - watch: leaves the floor bare for the watch's frame.
    ///   - time: seconds on the idle clock; the look's own idle plays now and then. Nil for a still.
    func dressed(for card: IdentityKind?, in mode: Mode, watch: Bool = false, time: TimeInterval? = nil) -> RunnerPose {
        var pose = self
        pose.cardLook = mode == .boxing ? RunnerCardLook(card: card) : nil
        pose.watchFrame = watch
        if let time, let look = pose.cardLook, pose.holdsCardProps, !pose.bedtime, let length = look.beatLength,
            let beat = IdleClock.beat(at: time, every: 24, spread: 6, lengths: [length], seed: Self.seed &+ 0x30)
        {
            pose.play(look, at: CGFloat(beat.phase))
        }
        // The gym bag shows with `bagLift`; 0 keeps it on the floor by the door. UI 审核 10/14 (位置规划图 §12):
        // the watch draws nothing on the floor, its bottom edge would leave only a scrap of the bag.
        if pose.cardLook == .fitness, !watch, pose.holdsCardProps, pose.bagLift < 0 { pose.bagLift = 0 }
        return pose
    }

    // Placement map: one thing per place. Whatever else HAKU holds, wears on the head or carries replaces the
    // card's props, the way the can goes away.
    /// Whether HAKU shows the card look's props: nothing else is in its hands, on its head or in the corner.
    var holdsCardProps: Bool {
        need == nil && activity == nil && life == nil && moment == nil && burst < 0 && dailyProp == nil
            && dailyScene == nil && walkFrom == nil && commuteLeg == nil && bathCall < 0 && bathDry < 0
            && thump < 0 && fistPump < 0 && !watchTap
    }
}

// 顺延身份卡 第一天待机 (UI 审核 R2, Mike 2026-10-14 item 4). Timings come from the approved preview.
extension RunnerCardLook {
    /// Length of the look's own idle in seconds, or nil for a look without one yet.
    var beatLength: TimeInterval? {
        switch self {
        case .dance, .music: 3
        case .ski: 3.5
        default: nil
        }
    }

    /// The parts of the look `t` seconds into its idle, starting from `visible`.
    func beatParts(at t: CGFloat, _ visible: inout Set<RunnerPart>) {
        switch self {
        case .dance:
            if t > Self.caught {
                visible.remove(.eyesChill)
                visible.insert(.eyesWork)
            }
            for note in [RunnerPart.speakerNoteA, .speakerNoteB] where Self.note(note, at: t) != nil {
                visible.insert(note)
            }
        case .music:
            let up = Self.chordsUp(at: t)
            if up > 0.02 { visible.insert(Self.chordShape(at: t)) }
            if Self.counting(at: t) {
                visible.remove(.mouthSmile)
                visible.insert(.countMouth)
            }
        case .ski:
            if t > 0.25, t < 2.25 {
                visible.remove(.wristbandHand)
                visible.insert(.goggleHand)
            }
            if Self.gogglesDown(at: t) > 0.6 { visible.remove(.eyesChill) }
            if t > 2.3, t < 3.4 {
                visible.insert(.breathPuff)
                if (t - 2.3) / 1.1 <= 0.5 {
                    visible.remove(.mouthSmile)
                    visible.insert(.countMouth)
                }
            }
        default:
            break
        }
    }

    /// How `part` moves `t` seconds into the look's idle, or nil when it stays put.
    func move(_ part: RunnerPart, at t: CGFloat) -> SceneMove? {
        var move = SceneMove()
        switch (self, part) {
        case (.dance, .jacket), (.dance, .stripeSport), (.dance, .hoodCollar), (.dance, .wristbandHand):
            // Shoulders shrug left and right in turn on each half beat.
            guard let beat = Self.halfBeat(at: t) else { return nil }
            move.offset.height = 1.6 * beat.dip
            move.angle = 2.2 * beat.side * Double(beat.dip)
            move.anchor = Self.point(60, 124)
        case (.dance, .danceSpeaker):
            guard let beat = Self.halfBeat(at: t), beat.side < 0 else { return nil }
            move.scale = 1 + 0.05 * beat.dip
            move.anchor = Self.point(11.75, 137.5)
        case (.dance, .speakerNoteA), (.dance, .speakerNoteB):
            guard let u = Self.note(part, at: t) else { return nil }
            move.offset = CGSize(width: 3 * sin(6 * u), height: -14 * u)
            move.opacity = Double(1 - u)
        case (.music, .chordHandA), (.music, .chordHandB):
            move.offset.height = 26 * (1 - Self.chordsUp(at: t))
        case (.ski, .skiGoggles):
            move.offset.height = 20 * Self.gogglesDown(at: t)
        case (.ski, .goggleHand):
            let hand = Self.ramp(t, 0.25, 0.45) * (1 - Self.ramp(t, 2.05, 2.25))
            move.offset = CGSize(width: 10 * (1 - hand), height: 20 * Self.gogglesDown(at: t) + 24 * (1 - hand))
        case (.ski, .breathPuff):
            let u = (t - 2.3) / 1.1
            move.offset = CGSize(width: 4 * u, height: -6 * u)
            move.scale = 0.5 + 0.7 * Self.ramp(u, 0, 0.5)
            move.anchor = Self.point(73, 84)
            move.opacity = Double(1 - Self.ramp(u, 0.55, 1))
        default:
            return nil
        }
        return move
    }

    /// Head nod and tilt `t` seconds into the look's idle.
    func head(at t: CGFloat) -> (dy: CGFloat, tilt: Double) {
        switch self {
        case .dance:
            guard let beat = Self.halfBeat(at: t) else { return (0, 0) }
            return (1.6 * beat.dip, -1.6 * beat.side * Double(beat.dip))
        case .music:
            guard t > 0.3, t < 2.6 else { return (0, 0) }
            return (1.2 * sin(Self.countPhase(at: t) * .pi), 0)
        default:
            return (0, 0)
        }
    }

    /// From here the dance stops: caught, it looks at you.
    private static let caught: CGFloat = 2.6

    /// The dip (0...1) and the side (-1 or 1) of the half beat at `t`, or nil once caught.
    private static func halfBeat(at t: CGFloat) -> (dip: CGFloat, side: Double)? {
        guard t <= caught else { return nil }
        let k = Int((t / 0.5).rounded(.down))
        return (sin((t - CGFloat(k) * 0.5) / 0.5 * .pi), k % 2 == 0 ? -1 : 1)
    }

    /// How far a speaker note has floated up (0..<1), or nil when it isn't showing.
    private static func note(_ note: RunnerPart, at t: CGFloat) -> CGFloat? {
        let u = (t - (note == .speakerNoteA ? 0.1 : 1.1)) / 1.4
        return u > 0 && u < 1 && t <= caught ? u : nil
    }

    /// 0 = the chord hand is down out of view, 1 = up at the chest.
    private static func chordsUp(at t: CGFloat) -> CGFloat {
        ramp(t, 0, 0.3) * (1 - ramp(t, 2.6, 2.95))
    }

    /// The chord shape held at `t`: it changes on every count.
    private static func chordShape(at t: CGFloat) -> RunnerPart {
        Int(((t - 0.3) / 0.375).rounded(.down)) % 2 == 0 ? .chordHandA : .chordHandB
    }

    /// How far into the current count `t` is, 0..<1.
    private static func countPhase(at t: CGFloat) -> CGFloat {
        ((t - 0.3).truncatingRemainder(dividingBy: 0.375)) / 0.375
    }

    /// Whether the mouth is open on a silent count.
    private static func counting(at t: CGFloat) -> Bool {
        t > 0.3 && t < 2.6 && countPhase(at: t) < 0.45
    }

    /// 0 = goggles on the forehead, 1 = pulled down over the eyes.
    private static func gogglesDown(at t: CGFloat) -> CGFloat {
        ramp(t, 0.45, 0.95) * (1 - ramp(t, 1.55, 2.05))
    }

    /// 0 before `a`, 1 after `b`, eased in between.
    private static func ramp(_ x: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let p = min(max((x - a) / (b - a), 0), 1)
        return p * p * (3 - 2 * p)
    }

    /// An SVG point as a unit point of the figure's frame.
    private static func point(_ x: CGFloat, _ y: CGFloat) -> UnitPoint {
        let box = RunnerArt.bounds
        return UnitPoint(x: (x - box.minX) / box.width, y: (y - box.minY) / box.height)
    }
}

extension RunnerPose {
    /// The pose `t` seconds into `look`'s own idle.
    fileprivate mutating func play(_ look: RunnerCardLook, at t: CGFloat) {
        cardBeat = t
        let head = look.head(at: t)
        headDy += head.dy
        headTilt += head.tilt
    }
}
