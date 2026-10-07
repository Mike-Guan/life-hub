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

    /// Her card's background, from the approved preview.
    public var color: Color {
        switch self {
        case .work: Color(hex: 0xBFEBD3)
        case .chill: Color(hex: 0x7FB7FF)
        case .tennis: Color(hex: 0xFFD1DC)
        case .desk: Color(hex: 0xDCCFFF)
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
                KuroPartView(part: part, shift: Self.shift(part, pose: pose))
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
        if look != .work {
            let mouth: KuroPart = pose.tired || pose.calm ? .mouthFlat : look == .tennis ? .mouthSmile : .mouthCat
            visible.insert(pose.mouthO ? .mouthO : mouth)
        }
        for item in pose.items where item.look == look {
            visible.insert(item.part)
            if let replaced = item.replaces { visible.remove(replaced) }
        }
        if let tap = pose.tap { apply(tap, progress: pose.tapProgress, to: &visible) }
        if pose.heart { visible.insert(.tapHeart) }
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
    /// How far the part moves, in SVG units.
    var shift: CGSize = .zero

    var body: some View {
        Canvas { context, size in
            RunnerDrawing.enterFigureSpace(&context, size: size)
            context.translateBy(x: shift.width, y: shift.height)
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
    let style: CompanionStyle
    let wearing: Set<KuroItem>
    let event: CompanionEvent?
    let showsBubble: Bool
    /// Called after KURO reacts to a tap, for example to switch the 副业 state.
    let onTap: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var bubble: String?
    @State private var bubbleTask: Task<Void, Never>?
    @State private var pop = 0
    @State private var tapStart: Date?
    @State private var tapKind: KuroTap?
    @State private var tapHeart = false
    @State private var tapTimes: [Date] = []
    @State private var pokes = 0
    @State private var unboxStart: Date?
    @State private var unboxItem: KuroItem?
    // Id of the last unboxing, shared with HAKU's view so each plays once.
    @AppStorage("companion.lastUnlock") private var lastUnlock = ""
    // Id of the last workout cheered, shared with HAKU's view so each plays once.
    @AppStorage("companion.lastCelebration") private var lastCelebration = ""
    @State private var crown = 0.0
    @State private var crownTurn = 0.0

    /// - Parameters:
    ///   - look: what she wears.
    ///   - energy: energy 0-100, or nil when unknown. Below 30 she looks tired; from 70 she looks bright.
    ///   - bedtime: `.on` makes her sleepy and slows her to a breath.
    ///   - need: what the user needs, which picks her lines.
    ///   - activity: what the user is doing, which picks her lines before anything else.
    ///   - moment: the moment of the day, which picks her lines unless an activity does. In the work look,
    ///     `.overtime` sits her at the desk with her chin on her hand.
    ///   - overtimeUntil: the late end of the work day, shown on a sign above her head during `.overtime`.
    ///   - style: `.watch` gives a tap a light tap on the wrist instead of a line.
    ///   - wearing: ids of her shop items she wears; each shows only in its own look.
    ///   - event: a one-off animation. `.unlock` with one of her items plays the unboxing once per id;
    ///     pass the item's `look` so it shows. `.celebrate` plays her look's tap move with a heart once per id.
    ///   - showsBubble: whether a tap shows a line in a speech bubble.
    ///   - onTap: called after she reacts to a tap.
    public init(
        look: KuroLook,
        energy: Double? = nil,
        bedtime: Bedtime = .off,
        need: CompanionNeed? = nil,
        activity: CompanionActivity? = nil,
        moment: CompanionMoment? = nil,
        overtimeUntil: Date? = nil,
        style: CompanionStyle = .standard,
        wearing: Set<String> = [],
        event: CompanionEvent? = nil,
        showsBubble: Bool = true,
        onTap: (() -> Void)? = nil
    ) {
        self.look = look
        self.energy = energy
        self.bedtime = bedtime
        self.need = need
        self.activity = activity
        self.moment = moment
        self.overtimeUntil = overtimeUntil
        self.style = style
        // The spin is a celebration, not something she wears.
        self.wearing = KuroItem.items(wearing).subtracting([.spin])
        self.event = event
        self.showsBubble = showsBubble
        self.onTap = onTap
    }

    public var body: some View {
        ZStack {
            // The same card as HAKU's: her look's color fills it, dimmed at bedtime.
            Rectangle()
                .fill(look.color)
                .overlay { Toy.ink.opacity(bedtime == .on ? 0.35 : 0) }
                .animation(.easeInOut(duration: 0.25), value: look)
                .animation(.easeInOut(duration: 0.8), value: bedtime)

            let paused = reduceMotion || scenePhase != .active
            TimelineView(.animation(minimumInterval: 1 / 30, paused: paused)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let tap = reaction(at: time)
                let unbox = unbox(at: time)
                let reacting = tap.map { self.pose.reacting($0.0, progress: $0.1, heart: tapHeart) }
                let pose = unbox != nil ? unboxPose : reacting ?? self.pose
                let pace = EnergyFace(energy: energy).speed
                let sleepy = bedtime == .on || pose.overtime
                let still = reduceMotion || unbox != nil
                let motion = sleepy ? IdleMotion.sleeping(time: time) : Self.motion(look, time: time * pace)
                let hop: CGFloat = still ? 0 : Self.hop(tap)
                ZStack {
                    KuroFigure(look: look, pose: still || tap != nil ? pose : pose.blink(at: time))
                        .scaleEffect(x: unbox?.spin ?? 1, y: max(unbox?.popOut ?? 1, 0.001), anchor: .bottom)
                    if let unbox {
                        GiftBox(progress: unbox.box, fill: RunnerPalette.cardboard, ribbon: KuroPalette.pink)
                    }
                }
                .aspectRatio(KuroArt.bounds.width / KuroArt.bounds.height, contentMode: .fit)
                .rotationEffect(.degrees(still ? 0 : motion.angle), anchor: .bottom)
                .offset(y: (still ? 0 : motion.dy) + hop)
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
            .modifier(WatchFigureFrame(isEnabled: false))
            .padding(.top, 24)
            .padding(.horizontal, 12)

            if unboxStart != nil {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: paused)) { context in
                    let time = context.date.timeIntervalSinceReferenceDate
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
        // Until she has her own close-up and crown moves (新角色清单), both play her tap reaction.
        .gesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in react() },
            including: style == .notification ? .none : .all
        )
        .modifier(CrownLook(isEnabled: style == .watch, crown: $crown))
        .onChange(of: crown) { old, new in crowned(by: new - old) }
        .task(id: listensForShakes) { await listenForShakes() }
        .sensoryFeedback(.impact(weight: .light), trigger: pokes)
        .onChange(of: look) { _, _ in
            pop += 1
            if unboxStart == nil { say(nil) }
        }
        .onAppear { playEventIfNew() }
        .onChange(of: event) { _, _ in playEventIfNew() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(look, bedtime: bedtime, pose: pose))
        .accessibilityAddTraits(showsBubble || style == .watch || onTap != nil ? .isButton : [])
    }

    private var listensForShakes: Bool { style != .notification && scenePhase == .active && !reduceMotion }

    // Until she has her own shake move (新角色清单), a shake plays her tap reaction.
    /// Reacts to each shake of the phone or the watch while the view is on screen and the app is active.
    private func listenForShakes() async {
        #if os(iOS) || os(watchOS)
        guard listensForShakes else { return }
        for await _ in DeviceShakes.stream() { react() }
        #endif
    }

    /// Plays her reaction to a tap: a body move for her look, and a line except on the watch. Taps during a move
    /// only change the line; too many in a row turn her away.
    private func react() {
        let now = Date.now
        if style == .watch { pokes += 1 }
        if tapKind == .turnAway, reaction(at: now.timeIntervalSinceReferenceDate) != nil { return }
        tapTimes = tapTimes.filter { now.timeIntervalSince($0) < CompanionView.pesterWindow } + [now]
        let talks = showsBubble && style != .watch
        if bedtime == .off, CompanionView.pestered(tapTimes, now: now, count: KuroTap.tooMany) {
            tapTimes = []
            play(.turnAway, at: now)
            if talks { say("……干嘛。") }
            onTap?()
            return
        }
        if reaction(at: now.timeIntervalSinceReferenceDate) == nil, unboxStart == nil, !pose.overtime {
            let sleepy = bedtime == .on || EnergyFace(energy: energy) == .low
            play(KuroTap(look: look, sleepy: sleepy), at: now)
        }
        if talks { say(Self.line(after: bubble, from: lines)) }
        onTap?()
    }

    /// Plays her reaction once the crown has turned a full step, counting `delta` in either direction.
    private func crowned(by delta: Double) {
        crownTurn += abs(delta)
        guard crownTurn >= 1 else { return }
        crownTurn = 0
        react()
    }

    /// Plays the unboxing or the workout cheer that `event` brings, if it is new.
    private func playEventIfNew() {
        playUnboxIfNew()
        guard bedtime == .off, let (id, kind) = Self.newCelebration(event, last: lastCelebration) else { return }
        lastCelebration = id
        // Until she has her own cheer per workout group (新角色清单), she plays her tap move with a heart.
        play(KuroTap(look: look, sleepy: false), at: .now)
        tapHeart = true
        if style == .watch { pokes += 1 }
        if showsBubble { say(KuroBubbleLines.celebration(kind), for: 4) }
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

    /// How far she hops at the start of a tap reaction, in points; turning away has no hop.
    nonisolated static func hop(_ tap: (KuroTap, Double)?) -> CGFloat {
        guard let tap, tap.0 != .turnAway, tap.1 < 0.35 else { return 0 }
        return -8 * CGFloat(sin(tap.1 / 0.35 * .pi))
    }

    private var pose: KuroPose {
        var pose = Self.pose(look, energy: energy, bedtime: bedtime, moment: moment, overtimeUntil: overtimeUntil)
        pose.items = wearing
        return pose
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
            if unboxItem == item { unboxStart = nil }
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
        bubbleTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { bubble = text }
        guard text != nil else { return }
        bubbleTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
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
    let wearing: Set<KuroItem>
    let framing: CompanionPortrait.Framing

    /// - Parameters:
    ///   - look: what she wears.
    ///   - energy: energy 0-100, or nil when unknown.
    ///   - bedtime: `.on` gives her sleepy eyes.
    ///   - wearing: ids of her shop items she wears; each shows only in its own look.
    ///   - framing: head to waist, or head only for small round widgets.
    public init(
        look: KuroLook,
        energy: Double? = nil,
        bedtime: Bedtime = .off,
        wearing: Set<String> = [],
        framing: CompanionPortrait.Framing = .full
    ) {
        self.look = look
        self.energy = energy
        self.bedtime = bedtime
        self.wearing = KuroItem.items(wearing).subtracting([.spin])
        self.framing = framing
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
