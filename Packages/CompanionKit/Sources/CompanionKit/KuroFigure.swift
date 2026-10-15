import HubCore
import SwiftUI

// Issue #164. Drawn exactly like the approved preview.
/// What KURO wears.
public enum KuroLook: String, CaseIterable, Sendable {
    /// Dark mask with a lit ω, a tablet and a lanyard badge.
    case work
    /// Lilac top and a hot drink.
    case chill
    /// White sportswear, a headband, a high ponytail and a racket.
    case tennis
    /// Glasses, a red pen and a stack of notebooks.
    case desk
    // Identity cards, batch 1 (第 1 批身份卡 预览, UI 审核 round 2 passed 2026-10-13).
    /// Boxing card: a violet top, a red headband, two red gloves and a small bag stand.
    case box
    /// Fitness card: her sportswear without the racket, holding a yoga block.
    case fitness
    /// Study card: her lilac top with an open notebook and a highlighter.
    case study
    /// Art card: a yellow smock, her tablet and a drawing pen.
    case art
    // Deferred identity cards (顺延身份卡 预览, UI 审核 round 2 passed 2026-10-14).
    /// Dance card: her sportswear and a small speaker on the floor.
    case dance
    /// Music card: her lilac top and a score she holds at her chest.
    case music
    /// Ski card: her sportswear and ski goggles up on her forehead.
    case ski

    // The only place the mode-to-outfit mapping lives, like `Mode.riveValue`.
    /// The look for `mode`: the identity card slot dresses her for `card`, or as her tennis day without one or
    /// for a card she has no look for yet; the side-hustle slot is her desk time.
    public init(mode: Mode, card: IdentityKind? = nil) {
        switch mode {
        case .work: self = .work
        case .chill: self = .chill
        case .boxing: self = Self.look(for: card)
        case .money: self = .desk
        }
    }

    private static func look(for card: IdentityKind?) -> KuroLook {
        switch card {
        case .boxing: .box
        case .fitness: .fitness
        case .study: .study
        case .art: .art
        case .dance: .dance
        case .music: .music
        case .ski: .ski
        default: .tennis
        }
    }

    /// Her card's background, from the approved preview.
    public var color: Color {
        switch self {
        case .work: Color(hex: 0xBFEBD3)
        case .chill: Color(hex: 0x7FB7FF)
        case .tennis: Color(hex: 0xFFD1DC)
        case .desk: Color(hex: 0xDCCFFF)
        // The card colors are placeholders until the shop palette (A4) settles them; each differs from the rest.
        case .box: Color(hex: 0xFFE14D)
        case .fitness: Color(hex: 0xFFC2D6)
        case .study: Color(hex: 0x9FD3FF)
        case .art: Color(hex: 0xFFC9A8)
        case .dance: Color(hex: 0xC9B8FF)
        case .music: Color(hex: 0xF2E8FF)
        case .ski: Color(hex: 0xE6E9EF)
        }
    }

    /// The identity card that dresses her in this look, or nil for a look of her own.
    var card: IdentityKind? {
        switch self {
        case .work, .chill, .tennis, .desk: nil
        case .box: .boxing
        case .fitness: .fitness
        case .study: .study
        case .art: .art
        case .dance: .dance
        case .music: .music
        case .ski: .ski
        }
    }

    /// The mode that dresses her in this look.
    var mode: Mode {
        switch self {
        case .work: .work
        case .chill: .chill
        case .tennis, .box, .fitness, .study, .art, .dance, .music, .ski: .boxing
        case .desk: .money
        }
    }
}

/// KURO's eyes.
enum KuroEyes: CaseIterable, Sendable {
    case open, closed, drowsy, bright, down, happy, surprised, low
}

/// Where each part of KURO is and how she looks right now.
struct KuroPose: Sendable {
    var eyes: KuroEyes = .open
    /// Eyes shut for a blink, replacing `eyes`.
    var blinking = false
    /// Low energy: flat mouth and no blush.
    var tired = false
    /// Full energy: bright eyes a size bigger, pink cheeks, ears up and sparkles by her head.
    var full = false
    /// Waiting out a late end at the desk, chin on hand.
    var overtime = false
    /// The late end shown on a sign above her head, as HH:mm, or nil for no sign.
    var sign: String?
    /// Shop items she wears; each shows only in its own look.
    var items: Set<KuroItem> = []
    /// Acting calm: flat mouth, blush kept.
    var calm = false
    /// A round open mouth, replacing her look's mouth.
    var mouthO = false
    /// The reaction to a tap she is playing, if any.
    var tap: KuroTap?
    /// How far into `tap` she is, 0..<1.
    var tapProgress = 0.0
    /// Whether the heart thought bubble shows.
    var heart = false
    /// The small idle move she is playing, if any.
    var idle: KuroIdle?
    /// How far into `idle` she is, 0..<1.
    var idleProgress = 0.0
    /// The home scene she is playing, if any: the invite, a walk or the bath.
    var scene: KuroScene?

    /// The resting pose for `look` at `energy` (0-100, or nil when unknown); `bedtime` makes her sleepy.
    init(look: KuroLook, energy: Double?, bedtime: Bedtime = .off) {
        if bedtime == .on {
            eyes = .drowsy
            return
        }
        switch EnergyFace(energy: energy) {
        case .low:
            eyes = .low
            tired = true
        case .high:
            eyes = .bright
            full = true
        case .mid:
            eyes = look == .tennis ? .bright : look == .desk ? .down : .open
        }
    }

    /// The same pose with `eyes`.
    func showing(_ eyes: KuroEyes) -> KuroPose {
        var pose = self
        pose.eyes = eyes
        return pose
    }

    /// The same pose blinking at `time`, 2.5-6 s apart on her own stream; slow and heavy with low eyes,
    /// never with drowsy eyes.
    func blink(at time: TimeInterval) -> KuroPose {
        var pose = self
        switch eyes {
        case .drowsy:
            // Bedtime eyes are already half shut; a blink would read as falling asleep.
            break
        case .low:
            // KURO-22: tired, she still blinks, just slower and longer.
            pose.blinking = IdleClock.blink(at: time * 0.6, seed: KuroIdle.seed) < 0.5
        default:
            pose.blinking = IdleClock.blink(at: time, seed: KuroIdle.seed) < 0.5
        }
        return pose
    }
}

/// KURO in one look and pose, drawn from vector parts.
struct KuroFigure: View {
    let look: KuroLook
    let pose: KuroPose
    /// Holds her props higher and leaves off what sits on the floor or her lap, so the watch's bottom edge cuts
    /// nothing.
    var watch = false

    var body: some View {
        let parts = Self.parts(for: look, pose: pose, watch: watch)
        let hatted = parts.contains(.setPicnicHat) || parts.contains(.setRainHat)
        ZStack {
            ForEach(parts, id: \.self) { part in
                KuroPartView(
                    part: part, shift: Self.offset(part, pose: pose, hatted: hatted), turn: Self.turn(part, pose: pose)
                )
                .opacity(Self.opacity(part, pose: pose))
            }
            if pose.overtime, let sign = pose.sign {
                RunnerTextView(text: RunnerText(string: sign, x: 60, y: -1, size: 9, color: KuroPalette.ink))
            }
        }
        .aspectRatio(KuroArt.bounds.width / KuroArt.bounds.height, contentMode: .fit)
    }

    /// Visible parts in back-to-front order; `watch` swaps her low props for the raised watch ones and leaves off
    /// what sits on the floor or her lap.
    nonisolated static func parts(for look: KuroLook, pose: KuroPose, watch: Bool = false) -> [KuroPart] {
        var visible: Set<KuroPart> = [.hairBack, .earL, .earR, .faceBase, .hairFringe, .catEars]
        visible.formUnion(outfit(look))
        visible.insert(pose.blinking ? .eyesClosed : part(pose.eyes))
        if !pose.tired { visible.insert(.blush) }
        // Issue #236 (correction preview v6): full reads apart from okay at a glance, even on the watch.
        if pose.full {
            // UI 审核 2026-10-13: the round cheeks replace the oval blush rather than smudging over it.
            visible.remove(.blush)
            visible.formUnion([.cheeksFull, .sparkle])
            if visible.contains(.eyesBright) {
                visible.remove(.eyesBright)
                visible.insert(.eyesFull)
            }
        }
        if pose.overtime {
            // Her chin rests on her hand, so whatever she held in front of her is put down.
            visible.subtract([.workTablet, .workStylus, .gymBlock, .studyNotebook, .scoreSheet, .scoreFinger])
            visible.formUnion([.overtimeDesk, .overtimeHand])
            if pose.sign != nil { visible.insert(.overtimeSign) }
        }
        if look != .work {
            let mouth: KuroPart =
                pose.tired || pose.calm ? .mouthFlat : Self.smiling.contains(look) ? .mouthSmile : .mouthCat
            visible.insert(pose.mouthO ? .mouthO : mouth)
        }
        for item in pose.items where item.look == look && item.clothes == nil {
            visible.insert(item.part)
            if let replaced = item.replaces { visible.remove(replaced) }
        }
        pose.scene?.dress(look, items: pose.items, &visible)
        if let tap = pose.tap {
            apply(tap, progress: pose.tapProgress, to: &visible)
            // The rubbing hand comes up on her arm, in her look's sleeve; in gloves the left one comes off, and the
            // finger on the score is that hand.
            if visible.contains(.tapRub) {
                visible.insert(rubSleeve(look))
                visible.subtract([.boxGloveL, .scoreFinger])
            }
        }
        if pose.heart { visible.insert(.tapHeart) }
        if pose.tap == nil, let idle = pose.idle { idle.apply(pose.idleProgress, to: &visible) }
        // One top or set per mode, so the first worn one in catalog order is the only one.
        let worn = KuroItem.allCases.filter { $0.look == look && pose.items.contains($0) }
        if let clothes = worn.lazy.compactMap(\.clothes).first {
            dress(look, in: clothes, back: pose.tap == .turnAway, &visible)
        }
        if watch { raise(&visible) }
        return KuroPart.allCases.filter { visible.contains($0) }
    }

    // Her own top stays wherever a scene or tap leaves it, so the clothes go only where it is drawn. UI 审核
    // 2026-10-14: from behind, no front pattern shows, and the set hats look the same from behind.
    /// Swaps her own top, sleeves and, for the rain set, cat ears in `visible` for `clothes`; when `back`, the top
    /// is the clothes' plain back.
    nonisolated private static func dress(
        _ look: KuroLook, in clothes: KuroClothes, back: Bool, _ visible: inout Set<KuroPart>
    ) {
        if visible.remove(jacket(look)) != nil {
            visible.insert(back ? clothes.back : clothes.top)
            // A hat goes where her cat ears are; the bath towel takes both off. The rain hat draws its own ears.
            if let hat = clothes.hat, visible.contains(.catEars) {
                visible.insert(hat)
                if hat == .setRainHat { visible.remove(.catEars) }
            }
        }
        if visible.remove(rubSleeve(look)) != nil { visible.insert(clothes.rubSleeve) }
        if visible.remove(KuroScene.sleeve(look)) != nil { visible.insert(clothes.inviteSleeve) }
    }

    /// Her own top in `look`.
    nonisolated static func jacket(_ look: KuroLook) -> KuroPart {
        switch look {
        case .work: .jacketWork
        case .chill, .study, .music: .jacketChill
        case .tennis, .fitness, .dance, .ski: .jacketTennis
        case .desk: .jacketDesk
        case .box: .jacketBox
        case .art: .jacketSmock
        }
    }

    // UI 审核 2026-10-15: with a set hat on, the "…" bubble sat on the hat. Moved up and left it clears both hats
    // by 2 pt, and its small dots stay off her cat ears.
    /// How far her "…" thought bubble moves when she wears a set hat, in SVG units.
    nonisolated static let hattedDots = CGSize(width: -6, height: -16.5)

    /// How far `part` moves from where the SVG draws it, in SVG units; full energy raises her ears a little, and
    /// her thought bubble moves above a set hat when `hatted`.
    nonisolated static func offset(_ part: KuroPart, pose: KuroPose, hatted: Bool = false) -> CGSize {
        let moved = shift(part, pose: pose)
        let lift: CGFloat = pose.full && part == .catEars ? 3 : 0
        let dots = hatted && part == .tapDots ? hattedDots : .zero
        return CGSize(width: moved.width + dots.width, height: moved.height - lift + dots.height)
    }

    /// The looks in her sportswear, where she smiles.
    nonisolated private static let smiling: Set<KuroLook> = [.tennis, .fitness, .dance, .ski]

    /// How opaque `part` is for her idle move: notes, snow and the sneeze fade out.
    nonisolated static func opacity(_ part: KuroPart, pose: KuroPose) -> Double {
        guard pose.tap == nil, let idle = pose.idle else { return 1 }
        return idle.opacity(part, progress: pose.idleProgress)
    }

    // UI 审核 2026-10-14 (direction 2): the watch crop cuts her low props, so on the watch she holds each one
    // higher instead of the face getting smaller. The pen, stylus and badge have no room there and stay off.
    // UI 审核 2026-10-14 (位置规划图 §12): the watch draws nothing on the floor or on her lap; its bottom edge
    // leaves only a scrap of them.
    /// Swaps each low prop in `visible` for its raised watch version and hides what sits on the floor or her lap.
    nonisolated private static func raise(_ visible: inout Set<KuroPart>) {
        let raised: [KuroPart: KuroPart] = [
            .tennisRacket: .watchRacket, .deskBooks: .watchBooks, .chillCup: .watchCup, .workTablet: .watchTablet,
        ]
        for (low, high) in raised where visible.contains(low) {
            visible.remove(low)
            visible.insert(high)
        }
        visible.subtract([.deskPen, .workStylus, .workBadge, .itemFlower, .itemLamp, .itemBlanket, .danceSpeaker])
    }

    /// The parts only `look` wears.
    nonisolated private static func outfit(_ look: KuroLook) -> Set<KuroPart> {
        switch look {
        case .work: [.jacketWork, .workTablet, .workStylus, .maskWork, .workBadge]
        case .chill: [.jacketChill, .chillCup]
        case .tennis: [.tennisPonytail, .jacketTennis, .tennisHeadband, .tennisRacket]
        case .desk: [.jacketDesk, .deskGlasses, .deskBooks, .deskPen]
        case .box: [.tennisPonytail, .jacketBox, .boxHeadband, .boxGloveL, .boxGloveR, .boxSandbag]
        case .fitness: [.tennisPonytail, .jacketTennis, .gymBlock]
        case .study: [.jacketChill, .studyNotebook, .studyHighlighter]
        case .art: [.jacketSmock, .workTablet, .craftPen]
        case .dance: [.tennisPonytail, .jacketTennis, .danceSpeaker]
        case .music: [.jacketChill, .scoreSheet, .scoreFinger]
        case .ski: [.tennisPonytail, .jacketTennis, .skiGoggles]
        }
    }

    nonisolated private static func rubSleeve(_ look: KuroLook) -> KuroPart {
        switch look {
        case .work: .tapRubSleeveWork
        case .chill: .tapRubSleeveChill
        case .tennis, .fitness, .dance, .ski: .tapRubSleeveTennis
        case .desk: .tapRubSleeveDesk
        case .box: .tapRubSleeveBox
        case .study, .music: .tapRubSleeveChill
        case .art: .tapRubSleeveSmock
        }
    }

    nonisolated private static func part(_ eyes: KuroEyes) -> KuroPart {
        switch eyes {
        case .open: .eyesOpen
        case .closed: .eyesClosed
        case .drowsy: .eyesDrowsy
        case .bright: .eyesBright
        case .down: .eyesDown
        case .happy: .eyesHappy
        case .surprised: .eyesSurprised
        case .low: .eyesLow
        }
    }
}

extension KuroArt {
    /// The inks of `part`, built once instead of on every frame.
    static func cachedInks(_ part: KuroPart) -> [RunnerInk] {
        inkCache[part] ?? []
    }

    private static let inkCache: [KuroPart: [RunnerInk]] = Dictionary(
        uniqueKeysWithValues: KuroPart.allCases.map { ($0, inks($0)) }
    )
}

extension KuroArt {
    // UI-03 (UI 审核 2026-10-08): a tinted Lock Screen keeps only the inverted brightness, so her near-black
    // hair, mask and navy top came out as one solid block. Drawn white, they read as outlines like HAKU.
    /// `inks` with the dark fills turned white, for the line-art look on tinted Lock Screens and faces.
    static func lineArt(_ inks: [RunnerInk]) -> [RunnerInk] {
        inks.map { ink in
            var ink = ink
            if let fill = ink.fill, darkFills.contains(fill) { ink.fill = KuroPalette.white }
            return ink
        }
    }

    /// Fills too dark to read once a tinted Lock Screen inverts them.
    static let darkFills: Set<Color> = [KuroPalette.hair, KuroPalette.mask, KuroPalette.navy]
}

extension EnvironmentValues {
    /// Whether KURO's parts draw as line art.
    @Entry var kuroLineArt = false
}

/// Draws one `KuroPart` across the whole figure frame.
/// A turn or squash of one part about a point, in SVG units.
struct KuroTurn: Equatable, Sendable {
    /// The point the part turns about.
    var pivot: CGPoint
    /// The turn, in degrees.
    var angle: Double = 0
    /// The direction the squash runs along, in degrees from horizontal.
    var axis: Double = 0
    /// The width along `axis`; negative shows the back.
    var scale: CGFloat = 1
}

struct KuroPartView: View {
    let part: KuroPart
    /// How far the part moves, in SVG units.
    var shift: CGSize = .zero
    /// How the part turns about a point, if it does.
    var turn: KuroTurn?
    @Environment(\.kuroLineArt) private var lineArt

    var body: some View {
        Canvas { context, size in
            RunnerDrawing.enterFigureSpace(&context, size: size)
            context.translateBy(x: shift.width, y: shift.height)
            if let turn {
                context.translateBy(x: turn.pivot.x, y: turn.pivot.y)
                context.rotate(by: .degrees(turn.angle + turn.axis))
                context.scaleBy(x: turn.scale, y: 1)
                context.rotate(by: .degrees(-turn.axis))
                context.translateBy(x: -turn.pivot.x, y: -turn.pivot.y)
            }
            let inks = KuroArt.cachedInks(part)
            RunnerDrawing.draw(lineArt ? KuroArt.lineArt(inks) : inks, in: context)
        }
    }
}

/// KURO with an idle loop for her look; energy picks her face and a tap gets a line.
public struct KuroView: View {
    let look: KuroLook
    let energy: Double?
    let bedtime: Bedtime
    let need: CompanionNeed?
    let activity: CompanionActivity?
    let moment: CompanionMoment?
    let overtimeUntil: Date?
    let invite: String?
    let walking: HubPlace.Kind?
    let bath: Bool
    let style: CompanionStyle
    let wearing: Set<KuroItem>
    let event: CompanionEvent?
    let showsBubble: Bool
    /// Increment to play her cheer: her look's move with a hop.
    let cheer: Int
    /// Increment to play the nod after an answer: a blink and a small dip.
    let nods: Int
    /// Called after KURO reacts to a tap, for example to switch the 副业 state.
    let onTap: (() -> Void)?
    /// Called once she has answered a welcome back event.
    let onWelcomeDone: (() -> Void)?
    /// Called after she shows the towel round her head on a tap during bath time.
    let onBathDone: (() -> Void)?

    @Environment(\.frameClock) private var frameClock
    @Environment(\.companionHold) private var hold
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.frameReduceMotion) private var frameReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var dozing
    /// True for a moment after the watch screen comes back on, while the figure stays still.
    @State private var settling = false
    /// Set when the watch screen has been dimmed too long to keep listening for shakes.
    @State private var shakeGraceOver = false
    /// When the watch felt a shake with its screen dimmed, to play once the screen is back on.
    @State private var pendingShake: Date?
    @State private var dimmedID = UUID()
    @State private var bubble: String?
    @State private var bubbleTask: Task<Void, Never>?
    @State private var pop = 0
    @State private var tapStart: Date?
    @State private var nodStart: Date?
    @State private var tapKind: KuroTap?
    @State private var tapHeart = false
    @State private var tapTimes: [Date] = []
    @State private var pokes = 0
    @State private var unboxStart: Date?
    @State private var unboxItem: KuroItem?
    /// When the last unboxing ended, so her idle eases back in instead of jumping.
    @State private var unboxEnd: Date?
    @State private var inviteStart: Date?
    @State private var bathStart: Date?
    @State private var dryStart: Date?
    @State private var lookBackStart: Date?
    /// Her idle time since her pace last changed; nil until it does.
    @State private var idlePace: IdlePace?
    // Id of the last unboxing, shared with HAKU's view so each plays once.
    @AppStorage("companion.lastUnlock") private var lastUnlock = ""
    // Id of the last workout cheered, shared with HAKU's view so each plays once.
    @AppStorage("companion.lastCelebration") private var lastCelebration = ""
    // Day of the last off-work move, shared with HAKU's view so it plays once a day.
    @AppStorage("companion.lastOffWork") private var lastOffWork = ""
    // Ids of the last one-off moments, shared with HAKU's view so each plays once.
    @AppStorage("companion.lastStayHome") private var lastStayHome = ""
    @AppStorage("companion.lastStretched") private var lastStretched = ""
    @AppStorage("companion.lastRevived") private var lastRevived = ""
    @AppStorage("companion.lastTaskDone") private var lastTaskDone = ""
    @AppStorage("companion.lastWelcome") private var lastWelcome = ""

    private var reduceMotion: Bool { frameReduceMotion ?? systemReduceMotion }

    /// - Parameters:
    ///   - look: what she wears.
    ///   - energy: energy 0-100, or nil when unknown. Below 30 she looks tired; from 70 she looks bright.
    ///   - bedtime: `.on` makes her sleepy and slows her to a breath.
    ///   - need: what the user needs, which picks her lines.
    ///   - activity: what the user is doing, which picks her lines before anything else.
    ///   - moment: the moment of the day, which picks her lines unless an activity does. In the work look,
    ///     `.overtime` sits her at the desk with her chin on her hand.
    ///   - overtimeUntil: the late end of the work day, shown on a sign above her head during `.overtime`.
    ///   - invite: today's invite, written by the app. While set she points at the door and says it.
    ///   - walking: the place she just left; while set she walks with small steps.
    ///   - bath: bath time; she carries her towel and clothes off to the bath, and a tap shows her washed.
    ///   - style: `.watch` gives a tap a light tap on the wrist instead of a line.
    ///   - wearing: ids of her shop items she wears; each shows only in its own look.
    ///   - event: a one-off animation. `.unlock` with one of her items plays the unboxing once per id;
    ///     pass the item's `look` so it shows. `.celebrate` plays her look's tap move with a heart once per id.
    ///     `.offWork` plays her look's tap move once per day. Staying home, stretching, reviving, a planned task
    ///     done and a welcome back each play her look's tap move once per id.
    ///   - showsBubble: whether a tap shows a line in a speech bubble.
    ///   - cheer: increment to play her cheer.
    ///   - nods: increment to play the nod after an answer.
    ///   - onTap: called after she reacts to a tap.
    ///   - onWelcomeDone: called once she has answered a `.welcomeBack` event, even one already played.
    ///   - onBathDone: called after she shows the towel round her head on a tap during bath time.
    public init(
        look: KuroLook,
        energy: Double? = nil,
        bedtime: Bedtime = .off,
        need: CompanionNeed? = nil,
        activity: CompanionActivity? = nil,
        moment: CompanionMoment? = nil,
        overtimeUntil: Date? = nil,
        invite: String? = nil,
        walking: HubPlace.Kind? = nil,
        bath: Bool = false,
        style: CompanionStyle = .standard,
        wearing: Set<String> = [],
        event: CompanionEvent? = nil,
        showsBubble: Bool = true,
        cheer: Int = 0,
        nods: Int = 0,
        onTap: (() -> Void)? = nil,
        onWelcomeDone: (() -> Void)? = nil,
        onBathDone: (() -> Void)? = nil
    ) {
        self.look = look
        self.energy = energy
        self.bedtime = bedtime
        self.need = need
        self.activity = activity
        self.moment = moment
        self.overtimeUntil = overtimeUntil
        self.invite = invite
        self.walking = walking
        self.bath = bath
        self.style = style
        // The spin is a celebration, not something she wears.
        self.wearing = KuroItem.items(wearing).subtracting([.spin])
        self.event = event
        self.showsBubble = showsBubble
        self.cheer = cheer
        self.nods = nods
        self.onTap = onTap
        self.onWelcomeDone = onWelcomeDone
        self.onBathDone = onBathDone
    }

    public var body: some View {
        ZStack {
            // The same card as HAKU's: her look's color fills it, dimmed at bedtime.
            Rectangle()
                .fill(look.color)
                .overlay { Toy.ink.opacity(bedtime == .on ? 0.35 : 0) }
                .animation(.easeInOut(duration: 0.25), value: look)
                .animation(.easeInOut(duration: 0.8), value: bedtime)

            let paused = CompanionView.paused(
                reduceMotion: reduceMotion, scenePhase: scenePhase, dozing: dozing, settling: settling
            )
            TimelineView(.animation(minimumInterval: frameInterval, paused: paused)) { context in
                let time = (frameClock ?? context.date).timeIntervalSinceReferenceDate
                let tap = reaction(at: time)
                let unbox = unbox(at: time)
                let homeScene = tap == nil && unbox == nil ? scene(at: time) : nil
                // Her slot's own move plays between taps; with reduced motion she keeps only the slot's face.
                let slotMove = tap == nil && unbox == nil && !reduceMotion ? slot?.move(in: look, at: time) : nil
                let reacting = (tap ?? slotMove).map {
                    self.pose.reacting($0.0, progress: $0.1, heart: tap != nil && tapHeart)
                }
                // KURO-04 (UI 审核 2026-10-09): with the watch screen dimmed she dozes, eyes shut and body still,
                // instead of freezing mid-hop or mid-blink.
                let nod = Self.nod(since: nodStart, at: time)
                let awake = unbox != nil ? unboxPose : reacting ?? scened(homeScene)
                // 「……嗯。」 (Issue #236): one blink at the start of the nod.
                let pose = dozing ? self.pose.showing(.closed) : (nod ?? 1) < 0.1 ? awake.showing(.closed) : awake
                let sleepy = bedtime == .on || pose.overtime || slot == .tired
                let still = Self.holdsStill(reduceMotion: reduceMotion, unboxing: unbox != nil, dozing: dozing)
                // KURO-16: her idle runs on from where it was when her pace changes, and eases back in after
                // an unboxing.
                let idleTime = idlePace?.phase(at: time) ?? time * pace
                let ease = Self.settle(since: unboxEnd, at: time)
                // Out being active she bounces like on her tennis day.
                let loop = slot == .active ? KuroLook.tennis : look
                let motion =
                    sleepy ? IdleMotion.sleeping(time: time) : homeScene?.motion ?? Self.motion(loop, time: idleTime)
                let hop: CGFloat = still ? 0 : Self.hop(tap ?? (slot?.hops == true ? slotMove : nil))
                // Her small idle moves play only in the plain idle.
                let busy = still || tap != nil || slot != nil || homeScene != nil || sleepy
                let fidget = busy ? nil : KuroIdle.at(idleTime, look: look)
                ZStack {
                    KuroFigure(
                        look: look, pose: still || tap != nil ? pose : pose.blink(at: time).idling(fidget),
                        watch: style == .watch
                    )
                    .scaleEffect(x: unbox?.spin ?? 1, y: max(unbox?.popOut ?? 1, 0.001), anchor: .bottom)
                    if let unbox {
                        GiftBox(progress: unbox.box, fill: RunnerPalette.cardboard, ribbon: KuroPalette.pink)
                    }
                }
                .aspectRatio(KuroArt.bounds.width / KuroArt.bounds.height, contentMode: .fit)
                .rotationEffect(.degrees(still ? 0 : motion.angle * ease), anchor: .bottom)
                .offset(y: (still ? 0 : motion.dy * ease + Self.nodDip(nod)) + hop)
            }
            .id(look)
            .transition(.opacity)
            .keyframeAnimator(initialValue: Squash(), trigger: pop) { content, value in
                content.scaleEffect(x: value.x, y: value.y, anchor: .bottom)
            } keyframes: { _ in
                Squash.tap()
            }
            .modifier(WatchFigureFrame(isEnabled: style == .watch))
            .padding(.top, Self.topInset(style))
            .padding(.horizontal, 12)
            // Every look change fades in 0.3 s, also when the mode switched on its own (HAKU-05).
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: look)

            if unboxStart != nil {
                TimelineView(.animation(minimumInterval: frameInterval, paused: paused)) { context in
                    let time = (frameClock ?? context.date).timeIntervalSinceReferenceDate
                    if unbox(at: time)?.stars == true {
                        KuroStarBubble(time: time).frame(width: 72).padding(10)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }

            if showsBubble, let bubble {
                SpeechBubble(text: bubble)
                    .padding(12)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: style == .watch ? .bottom : .topLeading
                    )
                    .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { react() }
        // Until she has her own close-up (新角色清单), a long press plays her tap reaction unless the app
        // handles it.
        .gesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in CompanionHold.release(hold) { react() } },
            including: style == .standard ? .all : .none
        )
        // On the watch the press must not take the swipe from the pages.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in CompanionHold.release(hold) { react() } },
            including: style == .watch ? .all : .none
        )
        .task(id: listensForShakes) { await listenForShakes() }
        .sensoryFeedback(.impact(weight: .light), trigger: pokes)
        .onChange(of: pace) { old, new in
            let now = Date.now.timeIntervalSinceReferenceDate
            idlePace = (idlePace ?? IdlePace(time: 0, phase: 0, pace: old)).changing(to: new, at: now)
        }
        .onChange(of: look) { _, _ in
            pop += 1
            if unboxStart == nil { say(nil) }
        }
        .onAppear {
            playEventIfNew()
            finishWelcomeIfNeeded()
            if invite != nil { startInvite() }
            if let walking { say(KuroScene.walkLine(from: walking), for: 3) }
            if bath { startBath() }
        }
        .onChange(of: invite) { _, new in
            if new != nil { startInvite() }
        }
        .onChange(of: walking) { _, new in
            if let new, bedtime == .off { say(KuroScene.walkLine(from: new), for: 3) }
        }
        .onChange(of: bath) { _, new in
            // The view lives for days, so each evening's bath time starts unwashed.
            dryStart = nil
            if new { startBath() }
        }
        .onChange(of: event) { _, _ in
            playEventIfNew()
            finishWelcomeIfNeeded()
        }
        .onChange(of: nods) { _, _ in nodStart = .now }
        .onChange(of: cheer) { _, _ in
            guard bedtime == .off, unboxStart == nil else { return }
            play(KuroTap(look: look, sleepy: false), at: .now)
        }
        .onChange(of: asleep) { _, new in
            guard style == .watch else { return }
            if new {
                listenAfterDimming()
                return
            }
            dimmedID = UUID()
            shakeGraceOver = false
            // Same as HAKU: she holds still for a second after the watch screen comes back on.
            settling = true
            Task {
                try? await Task.sleep(for: .seconds(1))
                settling = false
                playPendingShake()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(look, bedtime: bedtime, pose: pose))
        .accessibilityAddTraits(showsBubble || style == .watch || onTap != nil ? .isButton : [])
    }

    /// The app is in the background or the watch screen is dimmed.
    private var asleep: Bool { scenePhase != .active || dozing }

    /// Seconds between animation frames: fewer on the watch.
    private var frameInterval: Double { style == .watch ? 1 / 15 : 1 / 30 }

    // QA §5.1: a shake drops the wrist and dims the watch screen, so the watch listens for up to 5 s more after
    // dimming, then stops until the app is active again; in the background it stops at once.
    private var listensForShakes: Bool {
        guard style != .notification, !reduceMotion else { return false }
        guard style == .watch else { return scenePhase == .active }
        return scenePhase != .background && (!asleep || !shakeGraceOver)
    }

    /// Plays her reaction to a shake, or keeps it for when the dimmed watch screen comes back on.
    private func shaken() {
        if style == .watch, asleep || settling {
            pendingShake = .now
            return
        }
        react()
    }

    /// Plays a shake felt while the watch screen was dimmed, if it was recent.
    private func playPendingShake() {
        guard let shake = pendingShake else { return }
        pendingShake = nil
        if Date.now.timeIntervalSince(shake) < 10 { react() }
    }

    /// Stops listening for shakes 5 s after the watch screen dims, unless it comes back on first.
    private func listenAfterDimming() {
        let id = UUID()
        dimmedID = id
        Task {
            try? await Task.sleep(for: .seconds(5))
            if dimmedID == id { shakeGraceOver = true }
        }
    }

    // Until she has her own shake move (新角色清单), a shake plays her tap reaction.
    /// Reacts to each shake of the phone or the watch while the view is on screen and the app is active.
    private func listenForShakes() async {
        #if os(iOS) || os(watchOS)
        guard listensForShakes else { return }
        try? await Task.sleep(for: DeviceShakes.startDelay)
        guard !Task.isCancelled else { return }
        for await _ in DeviceShakes.stream() { shaken() }
        #endif
    }

    // PM 2026-10-13: on the watch she says a line from the same pool as on the phone, in the bottom bubble.
    /// Plays her reaction to a tap: a body move for her look, and a line. Taps during a move only change the
    /// line; too many in a row turn her away.
    private func react() {
        let now = Date.now
        if style != .watch, unboxStart == nil, reaction(at: now.timeIntervalSinceReferenceDate) == nil,
            reactInScene(at: now)
        {
            return
        }
        if style == .watch { pokes += 1 }
        if tapKind == .turnAway, reaction(at: now.timeIntervalSinceReferenceDate) != nil { return }
        tapTimes = tapTimes.filter { now.timeIntervalSince($0) < CompanionView.pesterWindow } + [now]
        if CompanionView.turnsAway(tapTimes, now: now, count: KuroTap.tooMany, bedtime: bedtime) {
            tapTimes = []
            play(.turnAway, at: now)
            if showsBubble { say("……干嘛。") }
            onTap?()
            return
        }
        if reaction(at: now.timeIntervalSinceReferenceDate) == nil, unboxStart == nil {
            let sleepy = bedtime == .on || EnergyFace(energy: energy) == .low
            // KURO-02: at the desk with her chin on her hand she stays seated and taps her cheek.
            play(pose.overtime ? .chinTap : KuroTap(look: look, sleepy: sleepy), at: now)
        }
        if showsBubble { say(Self.line(after: bubble, from: lines)) }
        onTap?()
    }

    /// Plays the unboxing, the workout cheer or the off-work move that `event` brings, if it is new.
    private func playEventIfNew() {
        playUnboxIfNew()
        guard bedtime == .off else { return }
        if let (id, kind) = Self.newCelebration(event, last: lastCelebration) {
            lastCelebration = id
            // Until she has her own cheer per workout group (新角色清单), she plays her tap move with a heart.
            play(KuroTap(look: look, sleepy: false), at: .now)
            tapHeart = true
            if style == .watch { pokes += 1 }
            if showsBubble { say(KuroBubbleLines.celebration(kind), for: 4) }
        }
        if let day = Self.newOffWork(event, last: lastOffWork) {
            lastOffWork = day
            // KURO-03: until she has her own off-work animation (新角色清单), she plays her tap move.
            play(KuroTap(look: look, sleepy: false), at: .now)
            if style == .watch { pokes += 1 }
            if showsBubble { say(KuroBubbleLines.offWork, for: 4) }
        }
        if let oneOff = KuroOneOff(event), oneOff.id != last(oneOff) {
            markPlayed(oneOff)
            // KURO-04: until she has her own animation for each (新角色清单), she plays her tap move.
            play(KuroTap(look: look, sleepy: false), at: .now)
            tapHeart = oneOff.heart
            if style == .watch { pokes += 1 }
            if showsBubble, let line = KuroBubbleLines.oneOff(event).randomElement() { say(line, for: 3) }
        }
    }

    /// Ends the welcome back for the app once her move has played, so what waits on it (unboxing) can show.
    private func finishWelcomeIfNeeded() {
        guard case .welcomeBack = event else { return }
        Task {
            try? await Task.sleep(for: .seconds(KuroOneOff.welcomeLength))
            onWelcomeDone?()
        }
    }

    /// The id stored for the last `oneOff` of its kind.
    private func last(_ oneOff: KuroOneOff) -> String {
        switch oneOff.kind {
        case .stayHome: lastStayHome
        case .stretched: lastStretched
        case .revived: lastRevived
        case .taskDone: lastTaskDone
        case .welcomeBack: lastWelcome
        }
    }

    private func markPlayed(_ oneOff: KuroOneOff) {
        switch oneOff.kind {
        case .stayHome: lastStayHome = oneOff.id
        case .stretched: lastStretched = oneOff.id
        case .revived: lastRevived = oneOff.id
        case .taskDone: lastTaskDone = oneOff.id
        case .welcomeBack: lastWelcome = oneOff.id
        }
    }

    /// The work day to play the off-work move for `event`, or nil when there is none or it already played that day.
    nonisolated static func newOffWork(_ event: CompanionEvent?, last: String) -> String? {
        CompanionView.newOffWork(event, last: last)
    }

    /// The workout id and group to cheer for `event`, or nil when there is none or it already played.
    nonisolated static func newCelebration(_ event: CompanionEvent?, last: String) -> (String, WorkoutSummary.Kind)? {
        guard case .celebrate(let id, let kind) = event, id != last else { return nil }
        return (id, kind)
    }

    private func play(_ kind: KuroTap, at now: Date) {
        tapKind = kind
        tapStart = now
        tapHeart = KuroTap.heart()
        pop += 1
    }

    /// The tap reaction and its progress (0..<1) at `time`, or nil when none is playing.
    private func reaction(at time: TimeInterval) -> (KuroTap, Double)? {
        guard let kind = tapKind, let start = tapStart?.timeIntervalSinceReferenceDate else { return nil }
        let progress = (time - start) / kind.duration
        return (0..<1).contains(progress) ? (kind, progress) : nil
    }

    /// Progress of the nod at `time` (0..<1), or nil when none is playing.
    nonisolated static func nod(since start: Date?, at time: TimeInterval) -> Double? {
        guard let start = start?.timeIntervalSinceReferenceDate else { return nil }
        let progress = (time - start) / CompanionView.nodDuration
        return (0..<1).contains(progress) ? progress : nil
    }

    /// How far she dips in the nod at `progress`, in points: down 4 and back, after the blink.
    nonisolated static func nodDip(_ progress: Double?) -> CGFloat {
        guard let progress, progress > 0.12, progress < 0.5 else { return 0 }
        return 4 * CGFloat(sin((progress - 0.12) / 0.38 * .pi))
    }

    // The tennis, boxing and gym ponytails reach the top of her bounds, where the phone bubble sits (unbox page).
    /// The space above the figure for `style`, in points.
    nonisolated static func topInset(_ style: CompanionStyle) -> CGFloat {
        style == .watch ? 24 : 38
    }

    /// Whether she holds still, with no sway, hop, blink or idle move: with Reduce Motion, while unboxing, or with
    /// the watch screen dimmed.
    nonisolated static func holdsStill(reduceMotion: Bool, unboxing: Bool, dozing: Bool) -> Bool {
        reduceMotion || unboxing || dozing
    }

    /// How far she hops at the start of a tap reaction, in points; turning away and the chin tap have no hop.
    nonisolated static func hop(_ tap: (KuroTap, Double)?) -> CGFloat {
        guard let tap, tap.0 != .turnAway, tap.0 != .chinTap, tap.1 < 0.35 else { return 0 }
        return -8 * CGFloat(sin(tap.1 / 0.35 * .pi))
    }

    private var pose: KuroPose {
        var pose = Self.pose(look, energy: energy, bedtime: bedtime, moment: moment, overtimeUntil: overtimeUntil)
        pose.items = wearing
        return slot?.dressing(pose) ?? pose
    }

    /// The fallback body language for her need, activity or moment; none at bedtime or during a home scene.
    private var slot: KuroSlot? {
        guard bedtime == .off, invite == nil, walking == nil, !bath else { return nil }
        return KuroSlot(need: need, activity: activity, moment: moment, look: look)
    }

    /// Her resting pose playing `scene`.
    private func scened(_ scene: KuroScene?) -> KuroPose {
        var pose = self.pose
        pose.scene = scene
        if let eyes = scene?.eyes { pose.eyes = eyes }
        return pose
    }

    /// The home scene playing at `time`, or nil when none is; none at bedtime. A tap's towel comes first, then
    /// the bath, the walk and the invite, like HAKU.
    private func scene(at time: TimeInterval) -> KuroScene? {
        guard bedtime == .off else { return nil }
        if let dry = dryStart?.timeIntervalSinceReferenceDate, (0..<KuroScene.driedLength).contains(time - dry) {
            return .dried(time: time - dry)
        }
        if bath { return .bath(time: time - (bathStart?.timeIntervalSinceReferenceDate ?? time)) }
        if let walking {
            let back = lookBackStart.map { (0..<1.2).contains(time - $0.timeIntervalSinceReferenceDate) } ?? false
            return .walking(from: walking, time: time, lookingBack: back)
        }
        guard invite != nil else { return nil }
        // Without a start she has already pointed and stands.
        return .invite(time: time - (inviteStart?.timeIntervalSinceReferenceDate ?? time - 10))
    }

    /// Answers a tap with the scene's own move; false when no scene is playing.
    private func reactInScene(at now: Date) -> Bool {
        guard let scene = scene(at: now.timeIntervalSinceReferenceDate) else { return false }
        switch scene {
        case .invite:
            // Points at the door again, without a word.
            inviteStart = now.addingTimeInterval(-KuroScene.pointing.lowerBound)
        case .walking:
            lookBackStart = now
        case .bath:
            dryStart = now
            say(KuroScene.driedLine, for: 3)
            Task {
                try? await Task.sleep(for: .seconds(KuroScene.driedLength))
                onBathDone?()
            }
        case .dried:
            break
        }
        pop += 1
        return true
    }

    private func startInvite() {
        guard bedtime == .off, let invite else { return }
        inviteStart = .now
        pop += 1
        say(invite, for: 5)
    }

    /// Starts the bath call; she says her line once she has stopped at the edge.
    private func startBath() {
        guard bedtime == .off else { return }
        let start = Date.now
        bathStart = start
        bubbleTask?.cancel()
        bubbleTask = Task {
            try? await Task.sleep(for: .seconds(KuroScene.bathLineAt))
            guard !Task.isCancelled, bathStart == start, dryStart == nil else { return }
            say(KuroScene.bathLine, for: 3)
        }
    }

    /// Her pose while unboxing: acting calm in the new item, with low eyes and a flat mouth.
    private var unboxPose: KuroPose {
        var pose = KuroPose(look: look, energy: nil).showing(.low)
        pose.calm = true
        pose.items = wearing.union(unboxItem.map { [$0] } ?? [])
        return pose
    }

    /// The unboxing at `time`, or nil when none is playing.
    private func unbox(at time: TimeInterval) -> KuroUnbox? {
        guard let item = unboxItem, let start = unboxStart?.timeIntervalSinceReferenceDate else { return nil }
        let progress = (time - start) / KuroUnbox.duration
        return (0..<1).contains(progress) ? KuroUnbox(item, progress: progress) : nil
    }

    /// Starts the unboxing when `event` brings a new one of her items.
    private func playUnboxIfNew() {
        guard let (id, item) = Self.newUnbox(event, last: lastUnlock) else { return }
        lastUnlock = id
        unboxItem = item
        unboxStart = .now
        say(nil)
        bubbleTask = Task {
            try? await Task.sleep(for: .seconds(KuroUnbox.duration * KuroUnbox.lineAt))
            guard !Task.isCancelled else { return }
            say(KuroBubbleLines.unlock(item.rawValue), for: 4)
        }
        Task {
            try? await Task.sleep(for: .seconds(KuroUnbox.duration))
            if unboxItem == item {
                unboxStart = nil
                unboxEnd = .now
            }
        }
    }

    /// The unboxing id and item to play for `event`, or nil when there is none, it isn't hers, or it already played.
    nonisolated static func newUnbox(_ event: CompanionEvent?, last: String) -> (String, KuroItem)? {
        guard case .unlock(let id, let itemID) = event, id != last, let item = KuroItem(rawValue: itemID) else {
            return nil
        }
        return (id, item)
    }

    /// Her pose for the inputs: during `.overtime` in the work look she waits at the desk with drowsy eyes.
    nonisolated static func pose(
        _ look: KuroLook,
        energy: Double?,
        bedtime: Bedtime,
        moment: CompanionMoment?,
        overtimeUntil: Date?,
        calendar: Calendar = .current
    ) -> KuroPose {
        var pose = KuroPose(look: look, energy: energy, bedtime: bedtime)
        guard bedtime == .off, look == .work, moment == .overtime else { return pose }
        pose.overtime = true
        pose.eyes = .drowsy
        pose.sign = overtimeUntil.map { signText($0, calendar: calendar) }
        return pose
    }

    /// `date` as HH:mm on a 24-hour clock in `calendar`'s time zone.
    nonisolated static func signText(_ date: Date, calendar: Calendar = .current) -> String {
        let time = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", time.hour ?? 0, time.minute ?? 0)
    }

    private var lines: [String] {
        CompanionLines.lines(for: look.mode, need: need, activity: activity, moment: moment, persona: .kuro)
    }

    /// A random line from `lines` that isn't `shown`, unless it is the only one.
    nonisolated static func line(after shown: String?, from lines: [String]) -> String? {
        let fresh = lines.filter { $0 != shown }
        return (fresh.isEmpty ? lines : fresh).randomElement()
    }

    private func say(_ text: String?, for seconds: Double = 2.4) {
        let text = text?.localized(for: .kuro)
        bubbleTask?.cancel()
        withAnimation(.smooth(duration: 0.3)) { bubble = text }
        guard text != nil else { return }
        bubbleTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { bubble = nil }
        }
    }

    /// The idle loop for `look`: work breathes and shifts her weight, chill, fitness and ski sway, tennis and
    /// boxing hop, dancing she sways to the beat, and at the desk, studying, drawing or reading a score she nods
    /// slowly over the page.
    nonisolated static func motion(_ look: KuroLook, time t: TimeInterval) -> IdleMotion {
        switch look {
        case .work: IdleMotion(dy: CGFloat(sin(t * 2 * .pi / 3.4)) * 1.5, angle: sin(t * 2 * .pi / 6.8))
        case .chill: IdleMotion(mode: .chill, time: t)
        case .tennis, .box: IdleMotion(mode: .boxing, time: t)
        // Keeping someone company at the gym, she sways calmly instead of bouncing.
        case .fitness: IdleMotion(mode: .chill, time: t)
        case .desk, .study, .art, .music:
            IdleMotion(dy: 2 * IdleClock.nod(at: t, period: 1.6, seed: KuroIdle.seed), angle: 0)
        // Dancing, she sways about her feet once a second; on the slopes she sways calmly like at the gym.
        case .dance: IdleMotion(dy: 0, angle: 2.6 * sin(t * 2 * .pi))
        case .ski: IdleMotion(mode: .chill, time: t)
        }
    }

    /// How much of her idle motion shows `t` seconds after an unboxing ended at `end`: eased from 0 to 1
    /// over half a second.
    nonisolated static func settle(since end: Date?, at t: TimeInterval) -> CGFloat {
        guard let end else { return 1 }
        let x = min(max((t - end.timeIntervalSinceReferenceDate) / 0.5, 0), 1)
        return CGFloat(x * x * (3 - 2 * x))
    }

    /// How fast her idle runs.
    private var pace: Double { EnergyFace(energy: energy).speed }

    nonisolated static func accessibilityLabel(_ look: KuroLook, bedtime: Bedtime, pose: KuroPose? = nil) -> String {
        if bedtime == .on { return "KURO，困了" }
        if let pose, pose.overtime { return pose.sign.map { "KURO，托着腮等到 \($0)" } ?? "KURO，托着腮等着" }
        return switch look {
        case .work: "KURO，在忙"
        case .chill: "KURO，捧着热饮"
        case .tennis: "KURO，拿着网球拍"
        case .desk: "KURO，戴着眼镜在批改"
        case .box: "KURO，戴着拳套"
        case .fitness: "KURO，抱着瑜伽砖"
        case .study: "KURO，拿着笔记本"
        case .art: "KURO，在平板上画画"
        case .dance: "KURO，跟着音乐摆"
        case .music: "KURO，捧着乐谱"
        case .ski: "KURO，戴着雪镜"
        }
    }
}

/// KURO standing still, for widgets and anywhere motion isn't wanted.
public struct KuroPortrait: View {
    let look: KuroLook
    let energy: Double?
    let bedtime: Bedtime
    let wearing: Set<KuroItem>
    let framing: CompanionPortrait.Framing
    let lineArt: Bool

    /// - Parameters:
    ///   - look: what she wears.
    ///   - energy: energy 0-100, or nil when unknown.
    ///   - bedtime: `.on` gives her sleepy eyes.
    ///   - wearing: ids of her shop items she wears; each shows only in its own look.
    ///   - framing: head to waist, or head only for small round widgets.
    ///   - lineArt: draws her dark fills white, for tinted Lock Screens and watch faces.
    public init(
        look: KuroLook,
        energy: Double? = nil,
        bedtime: Bedtime = .off,
        wearing: Set<String> = [],
        framing: CompanionPortrait.Framing = .full,
        lineArt: Bool = false
    ) {
        self.look = look
        self.energy = energy
        self.bedtime = bedtime
        self.wearing = KuroItem.items(wearing).subtracting([.spin])
        self.framing = framing
        self.lineArt = lineArt
    }

    public var body: some View {
        var pose = KuroPose(look: look, energy: energy, bedtime: bedtime)
        pose.items = wearing
        let figure = KuroFigure(look: look, pose: pose)
        return Group {
            switch framing {
            case .full: figure
            case .head: HeadCrop { figure }
            }
        }
        .environment(\.kuroLineArt, lineArt)
        .accessibilityLabel(KuroView.accessibilityLabel(look, bedtime: bedtime))
    }
}

#Preview("KURO") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))]) {
        ForEach(KuroLook.allCases, id: \.self) { look in
            KuroView(look: look).padding(8).background(Toy.paper)
        }
        KuroView(look: .chill, energy: 10).padding(8).background(Toy.paper)
        KuroView(look: .work, energy: 85).padding(8).background(Toy.paper)
        KuroView(look: .chill, bedtime: .on).padding(8).background(Toy.paper)
        ForEach(KuroEyes.allCases, id: \.self) { eyes in
            KuroFigure(look: .chill, pose: KuroPose(look: .chill, energy: nil).showing(eyes))
                .padding(8)
                .background(Toy.paper)
        }
        KuroPortrait(look: .tennis, framing: .head).frame(width: 80).background(Toy.paper)
        let all = Set(KuroItem.allCases.map(\.rawValue))
        ForEach([KuroLook.chill, .tennis, .desk], id: \.self) { look in
            KuroView(look: look, wearing: all).padding(8).background(Toy.paper)
        }
        KuroView(look: .tennis, event: .unlock(id: "preview", item: KuroItem.scrunchie.rawValue))
            .frame(height: 260)
        ForEach(KuroItem.allCases, id: \.self) { item in
            KuroItemIcon(item: item).frame(width: 48, height: 48).background(item.look.color)
        }
    }
    .padding()
}
