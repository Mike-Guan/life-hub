import HubCore
import SwiftUI

// Issue #164. Drawn exactly like the approved preview; her name and details stay out of the repo.
/// What Partner wears.
public enum PartnerLook: String, CaseIterable, Sendable {
    /// Dark mask with a lit ω, a tablet and a lanyard badge.
    case work
    /// Lilac top and a hot drink.
    case chill
    /// White sportswear, a headband, a high ponytail and a racket.
    case tennis
    /// Glasses, a red pen and a stack of notebooks.
    case desk
}

/// Partner's eyes.
enum PartnerEyes: CaseIterable, Sendable {
    case open, closed, drowsy, bright, down, happy, surprised, low
}

/// Where each part of Partner is and how she looks right now.
struct PartnerPose: Sendable {
    var eyes: PartnerEyes = .open
    /// Eyes shut for a blink, replacing `eyes`.
    var blinking = false
    /// Low energy: flat mouth and no blush.
    var tired = false

    /// The resting pose for `look` at `energy` (0-100, or nil when unknown).
    init(look: PartnerLook, energy: Double?) {
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
    func showing(_ eyes: PartnerEyes) -> PartnerPose {
        var pose = self
        pose.eyes = eyes
        return pose
    }

    /// The same pose blinking at `time`: every 4.5 s, except with low eyes.
    func blink(at time: TimeInterval) -> PartnerPose {
        var pose = self
        pose.blinking = eyes != .low && time.truncatingRemainder(dividingBy: 4.5) < 0.16
        return pose
    }
}

/// Partner in one look and pose, drawn from vector parts.
struct PartnerFigure: View {
    let look: PartnerLook
    let pose: PartnerPose

    var body: some View {
        ZStack {
            ForEach(Self.parts(for: look, pose: pose), id: \.self) { part in
                PartnerPartView(part: part)
            }
        }
        .aspectRatio(PartnerArt.bounds.width / PartnerArt.bounds.height, contentMode: .fit)
    }

    /// Visible parts in back-to-front order.
    nonisolated static func parts(for look: PartnerLook, pose: PartnerPose) -> [PartnerPart] {
        var visible: Set<PartnerPart> = [.hairBack, .earL, .earR, .faceBase, .hairFringe, .catEars]
        visible.formUnion(outfit(look))
        visible.insert(pose.blinking ? .eyesClosed : part(pose.eyes))
        if !pose.tired { visible.insert(.blush) }
        if look != .work { visible.insert(pose.tired ? .mouthFlat : look == .tennis ? .mouthSmile : .mouthCat) }
        return PartnerPart.allCases.filter { visible.contains($0) }
    }

    /// The parts only `look` wears.
    nonisolated private static func outfit(_ look: PartnerLook) -> Set<PartnerPart> {
        switch look {
        case .work: [.jacketWork, .workTablet, .maskWork, .workBadge]
        case .chill: [.jacketChill, .chillCup]
        case .tennis: [.tennisPonytail, .jacketTennis, .tennisHeadband, .tennisRacket]
        case .desk: [.jacketDesk, .deskGlasses, .deskBooks, .deskPen]
        }
    }

    nonisolated private static func part(_ eyes: PartnerEyes) -> PartnerPart {
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

extension PartnerArt {
    /// The inks of `part`, built once instead of on every frame.
    static func cachedInks(_ part: PartnerPart) -> [RunnerInk] {
        inkCache[part] ?? []
    }

    private static let inkCache: [PartnerPart: [RunnerInk]] = Dictionary(
        uniqueKeysWithValues: PartnerPart.allCases.map { ($0, inks($0)) }
    )
}

/// Draws one `PartnerPart` across the whole figure frame.
struct PartnerPartView: View {
    let part: PartnerPart

    var body: some View {
        Canvas { context, size in
            RunnerDrawing.enterFigureSpace(&context, size: size)
            RunnerDrawing.draw(PartnerArt.cachedInks(part), in: context)
        }
    }
}

/// Partner with an idle loop for her look; energy picks her face.
public struct PartnerView: View {
    let look: PartnerLook
    let energy: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// - Parameters:
    ///   - look: what she wears.
    ///   - energy: energy 0-100, or nil when unknown. Below 30 she looks tired; from 70 she looks bright.
    public init(look: PartnerLook, energy: Double? = nil) {
        self.look = look
        self.energy = energy
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || scenePhase != .active)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let pose = PartnerPose(look: look, energy: energy)
            let motion = Self.motion(look, time: time * EnergyFace(energy: energy).speed)
            PartnerFigure(look: look, pose: reduceMotion ? pose : pose.blink(at: time))
                .rotationEffect(.degrees(reduceMotion ? 0 : motion.angle), anchor: .bottom)
                .offset(y: reduceMotion ? 0 : motion.dy)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(look))
    }

    /// The idle loop for `look`: work nods like HAKU at work, chill sways, tennis hops and desk breathes.
    static func motion(_ look: PartnerLook, time t: TimeInterval) -> IdleMotion {
        switch look {
        case .work: IdleMotion(mode: .work, time: t)
        case .chill: IdleMotion(mode: .chill, time: t)
        case .tennis: IdleMotion(mode: .boxing, time: t)
        case .desk: IdleMotion.sleeping(time: t)
        }
    }

    static func accessibilityLabel(_ look: PartnerLook) -> String {
        switch look {
        case .work: "搭档在忙"
        case .chill: "搭档捧着热饮"
        case .tennis: "搭档拿着网球拍"
        case .desk: "搭档戴着眼镜在桌前"
        }
    }
}

/// Partner standing still, for widgets and anywhere motion isn't wanted.
public struct PartnerPortrait: View {
    let look: PartnerLook
    let energy: Double?
    let framing: CompanionPortrait.Framing

    /// - Parameters:
    ///   - look: what she wears.
    ///   - energy: energy 0-100, or nil when unknown.
    ///   - framing: head to waist, or head only for small round widgets.
    public init(look: PartnerLook, energy: Double? = nil, framing: CompanionPortrait.Framing = .full) {
        self.look = look
        self.energy = energy
        self.framing = framing
    }

    public var body: some View {
        let figure = PartnerFigure(look: look, pose: PartnerPose(look: look, energy: energy))
        Group {
            switch framing {
            case .full: figure
            case .head: HeadCrop { figure }
            }
        }
        .accessibilityLabel(PartnerView.accessibilityLabel(look))
    }
}

#Preview("Partner") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))]) {
        ForEach(PartnerLook.allCases, id: \.self) { look in
            PartnerView(look: look).padding(8).background(Toy.paper)
        }
        PartnerView(look: .chill, energy: 10).padding(8).background(Toy.paper)
        PartnerView(look: .work, energy: 85).padding(8).background(Toy.paper)
        ForEach(PartnerEyes.allCases, id: \.self) { eyes in
            PartnerFigure(look: .chill, pose: PartnerPose(look: .chill, energy: nil).showing(eyes))
                .padding(8)
                .background(Toy.paper)
        }
        PartnerPortrait(look: .tennis, framing: .head).frame(width: 80).background(Toy.paper)
    }
    .padding()
}
