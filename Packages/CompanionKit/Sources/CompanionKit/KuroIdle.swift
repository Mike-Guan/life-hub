import HubCore
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
    // Base-outfit idles (待机动作 补齐规格 v0 K4-K7, K10-K11; UI 三组 预览, UI 审核 2026-10-13). All 动态.
    // Whatever she holds for the card goes down out of the frame first, so her hands are free.
    /// Sport (fitness): both arms up, a rise onto her toes, and down again.
    case reach
    // No towel round her neck: it would appear from nowhere when the move starts; the towel comes up in her hand.
    /// Sport (fitness): a small towel comes up and wipes her forehead.
    case towel
    /// Craft (art): a lock of hair falls by her cheek and she tucks it behind her ear.
    case tuck
    /// Craft (art): both hands make a viewfinder and she shuts one eye.
    case frame
    /// Out (study): both hands straighten her collar.
    case collar
    /// Out (study): she looks down at her phone, smiles a little and puts it away.
    case phone
    // Deferred identity cards (顺延身份卡 预览, UI 审核 round 2 passed 2026-10-14).
    /// Dance: two notes rise from the speaker and fade, her ponytail swings a beat behind and her eyes smile.
    case groove
    /// Music: eyes on the score, one finger taps four places on it and her head nods with each tap.
    case score
    /// Ski: the mitten pats the snow off her shoulder twice, the snow falls, then a small sneeze.
    case snow
    // 动作展示总表 §3-3 (K5 for boxing): gloves stay on and the towel lives on her right shoulder (Mike 10/15 08:33Z,
    // K5 拳击擦汗 v1, UI 审核 round 2 passed). 动态.
    /// Boxing: the right glove takes the towel off her shoulder, wipes her brow twice and puts it back.
    case boxWipe

    /// KURO's idle stream; HAKU has his own, so the two never blink together.
    static let seed: UInt64 = 0x4B55

    /// How long the move lasts, in seconds.
    var length: TimeInterval {
        switch self {
        case .ears: 0.6
        case .stylus, .pen, .racket, .ponytail, .glasses: 1
        case .lookUp, .aside: 1.4
        case .blow, .draw, .towel, .frame, .boxWipe: 2
        case .reach: 3
        case .tuck: 1.2
        case .collar: 1.5
        case .phone: 2.5
        case .gloves: 1.2
        case .highlight: 1.6
        case .juggle: 3
        case .twirl: 2
        case .lap: 6
        case .groove, .score, .snow: 3
        }
    }

    // 动作展示总表 §3-3 (PM 10/15, UI 三组): cards without a look of their own wear her tennis look, but still get
    // their base outfit's moves.
    /// The moves `look` draws from, with `card`'s base outfit moves when she wears the tennis look for it.
    static func pool(_ look: KuroLook, card: IdentityKind? = nil) -> [KuroIdle] {
        let own = ownPool(look)
        guard look == .tennis, let base = card?.baseOutfit(for: .kuro) else { return own }
        switch base {
        case .sport: return own + [.reach, .towel]
        case .outing: return own + [.collar, .phone]
        case .craft: return own + [.tuck, .frame]
        }
    }

    /// The moves `look` draws from on its own.
    private static func ownPool(_ look: KuroLook) -> [KuroIdle] {
        switch look {
        case .work: [.ears, .stylus, .lookUp]
        case .chill: [.ears, .blow, .aside]
        case .tennis: [.ears, .racket, .ponytail, .juggle, .twirl]
        case .desk: [.ears, .glasses, .pen]
        // Boxing is an ordinary card for her (Mike 10/14): the gloves tapping together and the towel wipe.
        case .box: [.ears, .gloves, .ponytail, .boxWipe]
        case .fitness: [.ears, .ponytail, .lap, .reach, .towel]
        case .study: [.ears, .aside, .highlight, .collar, .phone]
        case .art: [.ears, .draw, .tuck, .frame]
        case .dance: [.ears, .ponytail, .groove]
        case .music: [.ears, .score]
        case .ski: [.ears, .snow]
        }
    }

    /// The move playing in `look` for `card` at idle time `t` and how far into it she is (0..<1), or nil between
    /// moves.
    static func at(_ t: TimeInterval, look: KuroLook, card: IdentityKind? = nil) -> (KuroIdle, Double)? {
        let pool = pool(look, card: card)
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
            visible.subtract(KuroFigure.lap.union([.chillCup]))
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
        case .groove:
            if (0.05..<0.95).contains(p) { Self.swapEyes(&visible, to: .eyesHappy) }
            for note in Self.notes where Self.rise(note.part, at: p) != nil { visible.insert(note.part) }
        case .score:
            if (0.05..<0.95).contains(p) { Self.swapEyes(&visible, to: .eyesDown) }
        case .snow:
            let t = p * length
            if t < 1.4 { visible.insert(.snowBits) }
            if (0.2..<1.5).contains(t) {
                visible.formUnion([.mittenArm, .mittenHand])
                Self.swapEyes(&visible, to: .eyesDown)
            }
            // Eyes shut and mouth open as the sneeze builds, then out it comes.
            if (1.7..<2.0).contains(t) {
                Self.eyesShut(&visible)
                Self.swapMouth(&visible, to: .mouthO)
            }
            if (2.0..<2.5).contains(t) {
                Self.eyesShut(&visible)
                Self.swapMouth(&visible, to: .mouthCat)
                visible.insert(.sneezePuff)
            }
        case .reach, .towel, .tuck, .frame, .collar, .phone:
            // Once the card props are all the way down they are out of the frame.
            if Self.hold(p, rise: 0.12, fall: 0.12) >= 1 { visible.subtract(putDown) }
            applyBase(p * length, to: &visible)
        case .boxWipe:
            // The glove takes the towel, comes up by her cheek, wipes, then puts it back.
            let t = p * length
            guard (0.12..<1.66).contains(t) else { return }
            visible.subtract([.boxShoulderTowel, .boxGloveR])
            switch t {
            case ..<0.36, 1.42...: visible.insert(.idleBoxGrab)
            case ..<0.56, 1.36...: visible.insert(.idleBoxRise)
            default: visible.insert(.idleBoxWipe)
            }
            if (0.36..<1.36).contains(t) { Self.eyesShut(&visible) }
        default:
            break
        }
    }

    /// The parts a base-outfit idle shows or hides `t` seconds in.
    private func applyBase(_ t: Double, to visible: inout Set<KuroPart>) {
        switch self {
        case .reach:
            if Self.reachUp(t) > 0.02 { visible.insert(.idleReach) }
            if (0.6..<2.2).contains(t) { Self.eyesShut(&visible) }
        case .towel:
            if (0.3..<1.7).contains(t) {
                visible.insert(.idleTowelWipe)
                Self.eyesShut(&visible)
            }
        case .tuck:
            if t < 0.6 { visible.insert(.idleStrand) }
            if (0.2..<1.1).contains(t) { visible.insert(.idleTuckHand) }
            if (0.3..<1.1).contains(t) { Self.swapEyes(&visible, to: .eyesDown) }
        case .frame:
            if (0.15..<1.75).contains(t) { visible.insert(.idleFrameHands) }
            if (0.45..<1.45).contains(t) { Self.swapEyes(&visible, to: .eyesWink) }
        case .collar:
            if (0.1..<1.4).contains(t) {
                visible.insert(.idleCollarHands)
                Self.swapEyes(&visible, to: .eyesDown)
            }
        case .phone:
            if (0.1..<2.3).contains(t) { visible.insert(.idlePhone) }
            if (0.35..<2).contains(t) { Self.swapEyes(&visible, to: .eyesDown) }
            if (1..<1.4).contains(t), visible.contains(.mouthCat) {
                visible.remove(.mouthCat)
                visible.insert(.mouthSmile)
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
        case .racket where part == .tennisRacket || part == .watchRacket: return CGSize(width: 0, height: -6 * twice)
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
        case .groove where part == .tennisPonytail:
            // A beat behind her sway, easing in and out so it starts and ends at rest.
            let swing = sin((p * length - 0.9 / (2 * .pi)) * 2 * .pi) * Self.hold(p, rise: 0.15, fall: 0.15)
            return CGSize(width: 3 * CGFloat(swing), height: 0)
        case .groove:
            guard let u = Self.rise(part, at: p) else { return .zero }
            return CGSize(width: 3 * CGFloat(sin(u * 6)), height: -14 * CGFloat(u))
        case .score where part == .scoreFinger:
            // The finger lifts off the page, taps four places on it and comes back to rest.
            let t = p * length
            let place: [CGFloat] = [0, 4, -6, 2]
            let lift = CGFloat(Self.hold(p, rise: 0.1, fall: 0.1))
            let at = place[min(3, Int(max(0, t - 0.4) / 0.5))]
            return CGSize(width: at * lift, height: -4 * (1 - Self.scoreTap(t)) * lift)
        case .score where Self.head.contains(part):
            return CGSize(width: 0, height: 0.8 * Self.scoreTap(p * length))
        case .snow where part == .snowBits:
            let fall = CGFloat(Self.ramp(p * length, 0.75, 1.35))
            return CGSize(width: 2 * fall, height: 24 * fall)
        case .snow where part == .mittenArm || part == .mittenHand:
            let t = p * length
            let up = CGFloat(Self.ramp(t, 0.2, 0.4) * (1 - Self.ramp(t, 1.25, 1.5)))
            let pat = CGFloat(Self.bump(t, 0.45, 0.7) + Self.bump(t, 0.8, 1.05))
            return CGSize(width: -14 * (1 - up), height: 30 * (1 - up) + 2.5 * pat)
        case .snow where Self.head.contains(part):
            let t = p * length
            if (1.7..<2.0).contains(t) { return CGSize(width: 0, height: -2 * Self.ramp(t, 1.7, 1.95)) }
            if (2.0..<2.5).contains(t) { return CGSize(width: 0, height: 3 * (1 - Self.ramp(t, 2.1, 2.5))) }
            return .zero
        case .reach, .towel, .tuck, .frame, .collar, .phone:
            return baseShift(part, at: p * length)
        // Two strokes across her brow.
        case .boxWipe where part == .idleBoxWipe:
            let t = p * length
            let wiping = Self.hold(p, from: 0.28, rise: 0.05, fall: 0.05, end: 0.68)
            return CGSize(width: 3 * sin((t - 0.56) * .pi / 0.2) * wiping, height: 0)
        default: return .zero
        }
    }

    /// The card props each base-outfit idle puts down.
    private var putDown: Set<KuroPart> {
        switch self {
        case .reach, .towel: Self.rackets.union([.gymBlock])
        case .tuck, .frame: Self.rackets.union([.workTablet, .watchTablet, .craftPen])
        case .collar, .phone: Self.rackets.union([.studyNotebook, .studyHighlighter])
        default: []
        }
    }

    // In the tennis look, worn for a card without a look of its own, the racket goes down instead.
    /// The rackets she may hold in the tennis look.
    private static let rackets: Set<KuroPart> = [.tennisRacket, .watchRacket, .itemGoldRacket]

    /// How far `part` moves `t` seconds into a base-outfit idle, in SVG units (timings from the approved preview).
    private func baseShift(_ part: KuroPart, at t: Double) -> CGSize {
        if putDown.contains(part) {
            let down = Self.hold(t / length, rise: 0.12, fall: 0.12)
            return CGSize(width: 0, height: 45 * down)
        }
        switch (self, part) {
        case (.reach, .idleReach): return CGSize(width: 0, height: 34 * (1 - Self.reachUp(t)))
        case (.reach, _) where !Self.ground.contains(part):
            // On her toes: the whole of her rises a little; what stands on the floor stays.
            let toe = Self.ease((t - 0.9) / 0.3) * (1 - Self.ease((t - 1.6) / 0.3))
            return CGSize(width: 0, height: -4 * toe)
        case (.towel, .idleTowelWipe):
            let lift = Self.ease((t - 0.3) / 0.25) * (1 - Self.ease((t - 1.45) / 0.25))
            return CGSize(width: sin((t - 0.3) * .pi * 3) * 4 * lift, height: 40 * (1 - lift))
        case (.tuck, .idleTuckHand):
            let up = Self.ease((t - 0.2) / 0.3) * (1 - Self.ease((t - 0.85) / 0.25))
            return CGSize(width: 0, height: 30 * (1 - up))
        case (.tuck, .idleStrand): return CGSize(width: 6 * Self.ease((t - 0.3) / 0.3), height: 0)
        case (.frame, .idleFrameHands):
            let up = Self.ease((t - 0.15) / 0.3) * (1 - Self.ease((t - 1.45) / 0.3))
            return CGSize(width: 0, height: 36 * (1 - up))
        case (.collar, .idleCollarHands):
            let up = Self.ease((t - 0.1) / 0.25) * (1 - Self.ease((t - 1.1) / 0.3))
            return CGSize(width: 0, height: 24 * (1 - up) + max(0, sin((t - 0.4) * .pi * 4)) * 1.2)
        case (.phone, .idlePhone):
            let up = Self.ease((t - 0.1) / 0.3) * (1 - Self.ease((t - 1.9) / 0.3))
            return CGSize(width: 0, height: 30 * (1 - up))
        default: return .zero
        }
    }

    /// The parts that stand on the floor.
    private static let ground: Set<KuroPart> = [.itemFlower, .itemLamp, .itemBag, .boxSandbag]

    /// How far her arms are up `t` seconds into the reach, 0...1.
    static func reachUp(_ t: Double) -> Double {
        ease(t / 0.5) * (1 - ease((t - 2.2) / 0.6))
    }

    /// Smoothstep of `x` clamped to 0...1.
    private static func ease(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }

    /// How opaque `part` is at `progress` (0..<1) into the move.
    func opacity(_ part: KuroPart, progress p: Double) -> Double {
        let t = p * length
        switch self {
        case .groove: return Self.rise(part, at: p).map { 1 - $0 } ?? 1
        case .snow where part == .snowBits: return 1 - Self.ramp(t, 0.75, 1.35)
        case .snow where part == .sneezePuff: return 1 - Self.ramp(t, 2.1, 2.5)
        default: return 1
        }
    }

    /// The two notes and when each leaves the speaker, in seconds into the groove.
    private static let notes: [(part: KuroPart, start: Double)] = [(.speakerNoteA, 0.2), (.speakerNoteB, 1.4)]

    /// How far `note` has risen (0..<1) at `p` into the groove, or nil when it isn't showing.
    private static func rise(_ note: KuroPart, at p: Double) -> Double? {
        guard let start = notes.first(where: { $0.part == note })?.start else { return nil }
        let u = (p * KuroIdle.groove.length - start) / 1.4
        return (0..<1).contains(u) ? u : nil
    }

    /// How far down the finger is on the score (0...1) at `t` seconds: four light taps half a second apart.
    private static func scoreTap(_ t: Double) -> CGFloat {
        CGFloat((0..<4).map { bump(t, 0.4 + Double($0) * 0.5, 0.7 + Double($0) * 0.5) }.max() ?? 0)
    }

    /// 0 → 1 eased from `a` to `b`.
    private static func ramp(_ t: Double, _ a: Double, _ b: Double) -> Double {
        let x = min(max((t - a) / (b - a), 0), 1)
        return x * x * (3 - 2 * x)
    }

    /// A half sine from `a` to `b`, 0 outside it.
    private static func bump(_ t: Double, _ a: Double, _ b: Double) -> Double {
        t <= a || t >= b ? 0 : sin(.pi * (t - a) / (b - a))
    }

    /// The parts of her head that nod together.
    private static let head: Set<KuroPart> = eyes.union([
        .hairBack, .earL, .earR, .faceBase, .blush, .hairFringe, .catEars, .tennisPonytail, .skiGoggles,
        .mouthCat, .mouthFlat, .mouthSmile, .mouthO, .sneezePuff,
    ])

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

    /// Replaces whichever mouth is showing with `mouth`.
    private static func swapMouth(_ visible: inout Set<KuroPart>, to mouth: KuroPart) {
        let mouths: Set<KuroPart> = [.mouthCat, .mouthFlat, .mouthSmile, .mouthO]
        guard !visible.isDisjoint(with: mouths) else { return }
        visible.subtract(mouths)
        visible.insert(mouth)
    }

    /// Replaces whichever eyes are showing with `eyes`.
    private static func swapEyes(_ visible: inout Set<KuroPart>, to eyes: KuroPart) {
        guard !visible.isDisjoint(with: Self.eyes) else { return }
        visible.subtract(Self.eyes)
        visible.insert(eyes)
    }

    /// The parts that are her eyes.
    private static let eyes: Set<KuroPart> = [
        .eyesOpen, .eyesClosed, .eyesDrowsy, .eyesBright, .eyesDown, .eyesHappy, .eyesSurprised, .eyesLow, .eyesWink,
        .eyesFull,
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
