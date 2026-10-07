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

    // The only place the mode-to-outfit mapping lives, like `Mode.riveValue`.
    /// The look for `mode`: boxing is her tennis day and the side-hustle slot is her desk time.
    public init(mode: Mode) {
        switch mode {
        case .work: self = .work
        case .chill: self = .chill
        case .boxing: self = .tennis
        case .money: self = .desk
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

    /// The same pose blinking at `time`: every 4.5 s, except with low or drowsy eyes.
    func blink(at time: TimeInterval) -> KuroPose {
        var pose = self
        pose.blinking = eyes != .low && eyes != .drowsy && time.truncatingRemainder(dividingBy: 4.5) < 0.16
        return pose
    }
}

/// KURO in one look and pose, drawn from vector parts.
struct KuroFigure: View {
    let look: KuroLook
    let pose: KuroPose

    var body: some View {
        ZStack {
            ForEach(Self.parts(for: look, pose: pose), id: \.self) { part in
                KuroPartView(part: part)
            }
        }
        .aspectRatio(KuroArt.bounds.width / KuroArt.bounds.height, contentMode: .fit)
    }

    /// Visible parts in back-to-front order.
    nonisolated static func parts(for look: KuroLook, pose: KuroPose) -> [KuroPart] {
        var visible: Set<KuroPart> = [.hairBack, .earL, .earR, .faceBase, .hairFringe, .catEars]
        visible.formUnion(outfit(look))
        visible.insert(pose.blinking ? .eyesClosed : part(pose.eyes))
        if !pose.tired { visible.insert(.blush) }
        if look != .work { visible.insert(pose.tired ? .mouthFlat : look == .tennis ? .mouthSmile : .mouthCat) }
        return KuroPart.allCases.filter { visible.contains($0) }
    }

    /// The parts only `look` wears.
    nonisolated private static func outfit(_ look: KuroLook) -> Set<KuroPart> {
        switch look {
        case .work: [.jacketWork, .workTablet, .maskWork, .workBadge]
        case .chill: [.jacketChill, .chillCup]
        case .tennis: [.tennisPonytail, .jacketTennis, .tennisHeadband, .tennisRacket]
        case .desk: [.jacketDesk, .deskGlasses, .deskBooks, .deskPen]
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

/// Draws one `KuroPart` across the whole figure frame.
struct KuroPartView: View {
    let part: KuroPart

    var body: some View {
        Canvas { context, size in
            RunnerDrawing.enterFigureSpace(&context, size: size)
            RunnerDrawing.draw(KuroArt.cachedInks(part), in: context)
        }
    }
}

/// KURO with an idle loop for her look; energy picks her face.
public struct KuroView: View {
    let look: KuroLook
    let energy: Double?
    let bedtime: Bedtime

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// - Parameters:
    ///   - look: what she wears.
    ///   - energy: energy 0-100, or nil when unknown. Below 30 she looks tired; from 70 she looks bright.
    ///   - bedtime: `.on` makes her sleepy and slows her to a breath.
    public init(look: KuroLook, energy: Double? = nil, bedtime: Bedtime = .off) {
        self.look = look
        self.energy = energy
        self.bedtime = bedtime
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || scenePhase != .active)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let pose = KuroPose(look: look, energy: energy, bedtime: bedtime)
            let pace = EnergyFace(energy: energy).speed
            let motion = bedtime == .on ? IdleMotion.sleeping(time: time) : Self.motion(look, time: time * pace)
            KuroFigure(look: look, pose: reduceMotion ? pose : pose.blink(at: time))
                .rotationEffect(.degrees(reduceMotion ? 0 : motion.angle), anchor: .bottom)
                .offset(y: reduceMotion ? 0 : motion.dy)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(look, bedtime: bedtime))
    }

    /// The idle loop for `look`: work nods like HAKU at work, chill sways, tennis hops and desk breathes.
    static func motion(_ look: KuroLook, time t: TimeInterval) -> IdleMotion {
        switch look {
        case .work: IdleMotion(mode: .work, time: t)
        case .chill: IdleMotion(mode: .chill, time: t)
        case .tennis: IdleMotion(mode: .boxing, time: t)
        case .desk: IdleMotion.sleeping(time: t)
        }
    }

    static func accessibilityLabel(_ look: KuroLook, bedtime: Bedtime) -> String {
        if bedtime == .on { return "KURO 困了" }
        return switch look {
        case .work: "KURO 在忙"
        case .chill: "KURO 捧着热饮"
        case .tennis: "KURO 拿着网球拍"
        case .desk: "KURO 戴着眼镜在桌前"
        }
    }
}

/// KURO standing still, for widgets and anywhere motion isn't wanted.
public struct KuroPortrait: View {
    let look: KuroLook
    let energy: Double?
    let bedtime: Bedtime
    let framing: CompanionPortrait.Framing

    /// - Parameters:
    ///   - look: what she wears.
    ///   - energy: energy 0-100, or nil when unknown.
    ///   - bedtime: `.on` gives her sleepy eyes.
    ///   - framing: head to waist, or head only for small round widgets.
    public init(
        look: KuroLook,
        energy: Double? = nil,
        bedtime: Bedtime = .off,
        framing: CompanionPortrait.Framing = .full
    ) {
        self.look = look
        self.energy = energy
        self.bedtime = bedtime
        self.framing = framing
    }

    public var body: some View {
        let figure = KuroFigure(look: look, pose: KuroPose(look: look, energy: energy, bedtime: bedtime))
        Group {
            switch framing {
            case .full: figure
            case .head: HeadCrop { figure }
            }
        }
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
    }
    .padding()
}
