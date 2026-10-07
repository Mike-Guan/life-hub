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

    /// The mode that dresses her in this look.
    var mode: Mode {
        switch self {
        case .work: .work
        case .chill: .chill
        case .tennis: .boxing
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
    /// Waiting out a late end at the desk, chin on hand.
    var overtime = false
    /// The late end shown on a sign above her head, as HH:mm, or nil for no sign.
    var sign: String?

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
            if pose.overtime, let sign = pose.sign {
                RunnerTextView(text: RunnerText(string: sign, x: 60, y: -1, size: 9, color: KuroPalette.ink))
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
        if pose.overtime {
            visible.remove(.workTablet)
            visible.formUnion([.overtimeDesk, .overtimeHand])
            if pose.sign != nil { visible.insert(.overtimeSign) }
        }
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

/// KURO with an idle loop for her look; energy picks her face and a tap gets a line.
public struct KuroView: View {
    let look: KuroLook
    let energy: Double?
    let bedtime: Bedtime
    let need: CompanionNeed?
    let activity: CompanionActivity?
    let moment: CompanionMoment?
    let overtimeUntil: Date?
    let showsBubble: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var bubble: String?
    @State private var bubbleTask: Task<Void, Never>?
    @State private var pop = 0

    /// - Parameters:
    ///   - look: what she wears.
    ///   - energy: energy 0-100, or nil when unknown. Below 30 she looks tired; from 70 she looks bright.
    ///   - bedtime: `.on` makes her sleepy and slows her to a breath.
    ///   - need: what the user needs, which picks her lines.
    ///   - activity: what the user is doing, which picks her lines before anything else.
    ///   - moment: the moment of the day, which picks her lines unless an activity does. In the work look,
    ///     `.overtime` sits her at the desk with her chin on her hand.
    ///   - overtimeUntil: the late end of the work day, shown on a sign above her head during `.overtime`.
    ///   - showsBubble: whether a tap shows a line in a speech bubble.
    public init(
        look: KuroLook,
        energy: Double? = nil,
        bedtime: Bedtime = .off,
        need: CompanionNeed? = nil,
        activity: CompanionActivity? = nil,
        moment: CompanionMoment? = nil,
        overtimeUntil: Date? = nil,
        showsBubble: Bool = true
    ) {
        self.look = look
        self.energy = energy
        self.bedtime = bedtime
        self.need = need
        self.activity = activity
        self.moment = moment
        self.overtimeUntil = overtimeUntil
        self.showsBubble = showsBubble
    }

    public var body: some View {
        ZStack {
            // The same card as HAKU's: the mode's color fills it, dimmed at bedtime.
            Rectangle()
                .fill(look.mode.color)
                .overlay { Toy.ink.opacity(bedtime == .on ? 0.35 : 0) }
                .animation(.easeInOut(duration: 0.25), value: look)
                .animation(.easeInOut(duration: 0.8), value: bedtime)

            let paused = reduceMotion || scenePhase != .active
            TimelineView(.animation(minimumInterval: 1 / 30, paused: paused)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let pose = self.pose
                let pace = EnergyFace(energy: energy).speed
                let sleepy = bedtime == .on || pose.overtime
                let motion = sleepy ? IdleMotion.sleeping(time: time) : Self.motion(look, time: time * pace)
                KuroFigure(look: look, pose: reduceMotion ? pose : pose.blink(at: time))
                    .rotationEffect(.degrees(reduceMotion ? 0 : motion.angle), anchor: .bottom)
                    .offset(y: reduceMotion ? 0 : motion.dy)
            }
            .id(look)
            .transition(.opacity)
            .keyframeAnimator(initialValue: Squash(), trigger: pop) { content, value in
                content.scaleEffect(x: value.x, y: value.y, anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack(\.x) {
                    CubicKeyframe(1.07, duration: 0.08)
                    SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                }
                KeyframeTrack(\.y) {
                    CubicKeyframe(0.9, duration: 0.08)
                    SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 12)

            if showsBubble, let bubble {
                SpeechBubble(text: bubble)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if showsBubble { say(Self.line(after: bubble, from: lines)) } }
        .onChange(of: look) { _, _ in
            pop += 1
            say(nil)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(look, bedtime: bedtime, pose: pose))
        .accessibilityAddTraits(showsBubble ? .isButton : [])
    }

    private var pose: KuroPose {
        Self.pose(look, energy: energy, bedtime: bedtime, moment: moment, overtimeUntil: overtimeUntil)
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

    private func say(_ text: String?) {
        bubbleTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { bubble = text }
        guard text != nil else { return }
        bubbleTask = Task {
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { bubble = nil }
        }
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

    nonisolated static func accessibilityLabel(_ look: KuroLook, bedtime: Bedtime, pose: KuroPose? = nil) -> String {
        if bedtime == .on { return "KURO，困了" }
        if let pose, pose.overtime { return pose.sign.map { "KURO，托着腮等到 \($0)" } ?? "KURO，托着腮等着" }
        return switch look {
        case .work: "KURO，在忙"
        case .chill: "KURO，捧着热饮"
        case .tennis: "KURO，拿着网球拍"
        case .desk: "KURO，戴着眼镜在批改"
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
