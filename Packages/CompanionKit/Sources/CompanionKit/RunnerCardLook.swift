import HubCore
import SwiftUI

// Drawn like the approved preview 第1批 身份卡 (haku-1-底衣, haku-4-身份卡).
/// What HAKU wears for an identity card other than boxing.
enum RunnerCardLook: CaseIterable, Sendable {
    /// Sport base, a visor, a racket in the right hand and a ball.
    case tennis
    /// Sport base and a small dumbbell in the right hand.
    case fitness
    /// Out base and an open book in both hands.
    case study
    /// Craft base, a sketchbook and a pencil.
    case art
    /// Sport base and the wristband.
    case dance
    /// Out base.
    case music
    /// Sport base and ski goggles on the forehead.
    case ski
    // 第2批 身份卡 (HAKU 第2批 说明, 10/13 draft); the swimming look is the PM's style B: no cap, goggles up.
    /// Sport base and swimming goggles pushed up on the hair.
    case swimming
    /// Sport base and a rolled mat standing in the right hand.
    case yoga
    /// Sport base and a plain ball on the fist with the wristband.
    case ball
    /// Out base, the backpack and a trekking pole in the right hand.
    case outdoor

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
        case .swimming: self = .swimming
        case .yoga: self = .yoga
        case .ball: self = .ball
        case .outdoor: self = .outdoor
        default: return nil
        }
    }

    /// Whether this look wears the sport base: the dark jacket with the orange stripe.
    var sporty: Bool {
        switch self {
        case .tennis, .fitness, .dance, .ski, .swimming, .yoga, .ball: true
        case .study, .art, .music, .outdoor: false
        }
    }

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
        case .dance: parts.formUnion([.eyesChill, .wristbandHand])
        case .music: parts.insert(.eyesWork)
        case .ski: parts.formUnion([.eyesChill, .wristbandHand, .skiGoggles])
        case .swimming: parts.formUnion([.eyesChill, .cheerGoggles])
        case .yoga: parts.formUnion([.eyesChill, .yogaMat, .matHand])
        case .ball: parts.formUnion([.eyesChill, .wristbandHand, .sportBall])
        case .outdoor: parts.formUnion([.eyesChill, .outPack, .outStraps, .outPole, .poleFist])
        }
        return parts
    }

    /// What the look holds in its hands, or the bare fist with the wristband.
    var held: Set<RunnerPart> {
        switch self {
        case .tennis: [.tennisRacket, .racketHand, .tennisBall]
        case .fitness: [.handWeight]
        case .study: [.book, .bookPage]
        case .art: [.sketchbook, .pencil]
        case .dance, .ski: [.wristbandHand]
        case .music, .swimming: []
        case .yoga: [.yogaMat, .matHand]
        case .ball: [.wristbandHand, .sportBall]
        case .outdoor: [.outPole, .poleFist]
        }
    }

    // Mike 2026-10-15: a card's own backdrop holds no items, so nothing stands in the corner.
    /// What the look puts aside while HAKU does something else: what it holds and what it wears over the base.
    var props: Set<RunnerPart> {
        held.union([.tennisVisor, .apron, .skiGoggles, .cheerGoggles, .outPack, .outStraps])
    }

    /// The jacket fill: dark for sport, the green off-work jacket for out and craft.
    var jacket: Color { sporty ? RunnerPalette.jacket : RunnerPalette.jacketChill }
}

extension RunnerPose {
    /// The same pose dressed for `card`, which only the identity card mode wears.
    /// - Parameters:
    ///   - watch: draws for the watch's frame.
    ///   - time: seconds on the idle clock; the look's own idle plays now and then. Nil for a still.
    func dressed(for card: IdentityKind?, in mode: Mode, watch: Bool = false, time: TimeInterval? = nil) -> RunnerPose {
        var pose = self
        pose.cardLook = mode == .boxing ? RunnerCardLook(card: card) : nil
        pose.watchFrame = watch
        if let time, let look = pose.cardLook, pose.holdsCardProps, !pose.bedtime {
            // The look's own idle, if it has one, and its base outfit's moves share one stream.
            let pool: [RunnerBaseIdle?] = (look.beatLength == nil ? [] : [nil]) + RunnerBaseIdle.pool(look)
            let lengths = pool.map { $0.map { Double($0.length) } ?? look.beatLength ?? 0 }
            if let beat = IdleClock.beat(at: time, every: 24, spread: 6, lengths: lengths, seed: Self.seed &+ 0x30) {
                pose.play(look, pool[beat.kind], at: CGFloat(beat.phase))
            }
        }
        return pose
    }

    // Placement map: one thing per place. Whatever else HAKU holds, wears on the head or carries replaces the
    // card's props, the way the can goes away.
    /// Whether HAKU shows the card look's props: nothing else is in its hands, on its head or in the corner.
    var holdsCardProps: Bool {
        need == nil && activity == nil && life == nil && moment == nil && (burst < 0 || swapping) && dailyProp == nil
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
        case .swimming: 3.2
        case .yoga: 4
        case .ball: 3.4
        case .outdoor: 3.6
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
        case .swimming:
            // UI 审核 10/13: the lenses are see-through, so the eyes stay and only blink under them.
            if t > 0.25, t < 2.25 { visible.insert(.goggleHand) }
            if t > 1.1, t < 1.35 { Self.swapEyes(&visible, to: .eyesClosed) }
            if t > 2.1, t < 3.0 { Self.swapEyes(&visible, to: .eyesWork) }
        case .yoga:
            if t > 0.45, t < 3.45 { visible.remove(.matHand) }
            if t > 0.3, t < 3.6 { visible.insert(.yogaPalms) }
            if t > 0.5, t < 2.9 { Self.swapEyes(&visible, to: .eyesClosed) }
            if t >= 2.9, t < 3.5 { Self.swapEyes(&visible, to: .eyesWork) }
        case .ball:
            if t > 0.3, t < 2.3 {
                visible.remove(.wristbandHand)
                visible.insert(.cheerBallHand)
            }
            if t > 2.4, t < 3.3 { Self.swapEyes(&visible, to: .eyesWork) }
        case .outdoor:
            if t > 0.45, t < 2.9 { visible.remove(.poleFist) }
            if t > 0.3, t < 3.05 { visible.insert(.browHand) }
            if t > 0.6, t < 2.9 { Self.swapEyes(&visible, to: t > 1.9 && t < 2.05 ? .eyesClosed : .eyesWork) }
            if t > 1.0, t < 1.9 { visible.insert(.windGust) }
        default:
            break
        }
    }

    /// Swaps whichever eyes are showing for `eyes`.
    private static func swapEyes(_ visible: inout Set<RunnerPart>, to eyes: RunnerPart) {
        let all: Set<RunnerPart> = [.eyesChill, .eyesWork, .lidsWork, .eyesClosed]
        guard !visible.contains(eyes), !visible.isDisjoint(with: all) else { return }
        visible.subtract(all)
        visible.insert(eyes)
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
        case (.swimming, .cheerGoggles):
            move.offset.height = 20 * Self.gogglesDown(at: t)
        case (.swimming, .goggleHand):
            let hand = Self.ramp(t, 0.25, 0.45) * (1 - Self.ramp(t, 2.05, 2.25))
            move.offset = CGSize(width: 10 * (1 - hand), height: 20 * Self.gogglesDown(at: t) + 24 * (1 - hand))
        case (.yoga, .matHand):
            move.opacity = Double(1 - Self.ramp(t, 0.3, 0.45) + Self.ramp(t, 3.45, 3.6))
        case (.yoga, .yogaPalms):
            move.angle = Self.sway(at: t)
            move.anchor = Self.point(60, 138)
            move.offset.height = 6 * (1 - Self.ramp(t, 0.3, 0.5) + Self.ramp(t, 3.4, 3.6))
            move.opacity = Double(Self.ramp(t, 0.3, 0.45) * (1 - Self.ramp(t, 3.45, 3.6)))
        case (.yoga, .jacket), (.yoga, .stripeSport), (.yoga, .hoodCollar):
            // The body sways; the mat stands still.
            move.angle = Self.sway(at: t)
            move.anchor = Self.point(60, 138)
        case (.ball, .sportBall):
            let spot = Self.ballSpot(at: t)
            move.offset = CGSize(width: spot.x, height: spot.y)
            move.angle = 720 * Double(Self.ramp(t, 0.4, 1.9)) + 180 * Double(Self.ramp(t, 2.3, 2.6))
            move.anchor = Self.point(104.5, 106)
        case (.outdoor, .outPole):
            // Leans on the pack while the hand shades the eyes.
            move.angle = -12 * Double(Self.ramp(t, 0.3, 0.6) * (1 - Self.ramp(t, 2.8, 3.1)))
            move.anchor = Self.point(111.8, 137)
        case (.outdoor, .poleFist):
            move.opacity = Double(1 - Self.ramp(t, 0.3, 0.45) + Self.ramp(t, 2.9, 3.05))
        case (.outdoor, .browHand):
            move.offset.height = 8 * (1 - Self.ramp(t, 0.3, 0.6) + Self.ramp(t, 2.75, 3.05))
            move.opacity = Double(Self.ramp(t, 0.3, 0.45) * (1 - Self.ramp(t, 2.9, 3.05)))
        case (.outdoor, .windGust):
            let u = (t - 1.0) / 0.9
            move.offset.width = 10 * u
            move.opacity = Double(Self.ramp(u, 0, 0.2) * (1 - Self.ramp(u, 0.7, 1)))
        default:
            return nil
        }
        return move
    }

    /// The eye offset `t` seconds into the look's idle, in SVG units.
    func eyes(at t: CGFloat) -> CGSize {
        switch self {
        // The eyes follow the ball down, then look away as if nothing fell.
        case .ball:
            CGSize(
                width: -3 * Self.ramp(t, 2.3, 2.5) * (1 - Self.ramp(t, 3.1, 3.3)),
                height: 3 * Self.ramp(t, 1.9, 2.1) * (1 - Self.ramp(t, 2.3, 2.5)))
        // Looking far ahead, a little to the right.
        case .outdoor: CGSize(width: 2 * Self.ramp(t, 0.6, 0.9) * (1 - Self.ramp(t, 2.6, 2.9)), height: 0)
        default: .zero
        }
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
        case .yoga:
            return (0, Self.sway(at: t))
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

    /// The yoga sway in degrees: left, right, then upright to look at you.
    private static func sway(at t: CGFloat) -> Double {
        Double(-6 * ramp(t, 0.7, 1.3) + 10 * ramp(t, 1.5, 2.2) - 4 * ramp(t, 2.4, 2.9))
    }

    // Up to the fingertip, two turns, then it drops, rolls by the foot and bounces back onto the fist.
    /// Where the ball is `t` seconds into the ball idle, as an offset from the fist in SVG units.
    private static func ballSpot(at t: CGFloat) -> CGPoint {
        if t < 1.9 { return CGPoint(x: 0, y: -27 * ramp(t, 0.15, 0.4)) }
        if t < 2.3 {
            let u = (t - 1.9) / 0.4
            return CGPoint(x: 4 * u, y: -27 + 51 * u * u)
        }
        if t < 2.6 { return CGPoint(x: 4 + 2 * ramp(t, 2.3, 2.6), y: 24) }
        let v = min((t - 2.6) / 0.5, 1)
        return CGPoint(x: 6 * (1 - v), y: 24 * (1 - v) - 14 * sin(v * .pi))
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
    /// The pose `t` seconds into `look`'s own idle, or into `idle` when given.
    mutating func play(_ look: RunnerCardLook, _ idle: RunnerBaseIdle?, at t: CGFloat) {
        cardBeat = t
        baseIdle = idle
        if let idle {
            let eyes = idle.eyes(look, at: t)
            eyesDx += eyes.width
            eyesDy += eyes.height
            headTilt += idle.tilt(look, at: t)
            shrug = idle.shrug(look, at: t)
            return
        }
        let head = look.head(at: t)
        headDy += head.dy
        headTilt += head.tilt
        let eyes = look.eyes(at: t)
        eyesDx += eyes.width
        eyesDy += eyes.height
    }
}
