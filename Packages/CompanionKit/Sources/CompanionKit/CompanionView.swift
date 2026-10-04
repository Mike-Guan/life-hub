import HubCore
import SwiftUI

// Draws RUNNER from vector parts with SwiftUI motion. When `runner.riv` exists this view
// switches to Rive internally; callers keep passing `mode`, `energy` and `cheer`.
/// RUNNER, reacting to the current mode and energy.
public struct CompanionView: View {
    let mode: Mode?
    /// Energy 0-100, or nil when unknown. Below 30 RUNNER looks tired; from 70 it looks bright.
    let energy: Double?
    /// What RUNNER acts out on top of the mode, or nil.
    let need: CompanionNeed?
    /// When `need` started. After 30 minutes of couch scrolling HAKU starts eyeing the gym bag.
    let needSince: Date?
    /// A one-off animation: celebrating a workout or going off work. Each event id plays once.
    let event: CompanionEvent?
    /// Today's invite, written by the app. While set, RUNNER gets up, jumps and says it.
    let invite: String?
    /// Increment to play the cheer jump.
    let cheer: Int
    /// `.on` turns RUNNER sleepy; each change to `.on` plays the good-night animation once.
    let bedtime: Bedtime
    /// What HAKU wears from the shop and keepsakes.
    let wardrobe: Wardrobe
    let style: CompanionStyle
    let showsBubble: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var pop = 0
    @State private var taps = 0
    @State private var goodnightStart: Date?
    // Seconds since the reference date of the last good-night animation, shared by every CompanionView.
    @AppStorage("companion.lastGoodnight") private var lastGoodnight: Double = 0
    @State private var celebrationStart: Date?
    @State private var celebrationKind: WorkoutSummary.Kind?
    @State private var inviteJumps = 0
    // Id of the last celebrated workout, shared by every CompanionView so each plays once.
    @AppStorage("companion.lastCelebration") private var lastCelebration = ""
    @State private var offWorkStart: Date?
    // Day of the last off-work animation, shared by every CompanionView so it plays once a day.
    @AppStorage("companion.lastOffWork") private var lastOffWork = ""
    @State private var bubble: String?
    @State private var bubbleTask: Task<Void, Never>?

    public init(
        mode: Mode?,
        energy: Double? = nil,
        need: CompanionNeed? = nil,
        needSince: Date? = nil,
        event: CompanionEvent? = nil,
        invite: String? = nil,
        cheer: Int = 0,
        bedtime: Bedtime = .off,
        wardrobe: Wardrobe = Wardrobe(),
        style: CompanionStyle = .standard,
        showsBubble: Bool = true
    ) {
        self.mode = mode
        self.energy = energy
        self.need = need
        self.needSince = needSince
        self.event = event
        self.invite = invite
        self.cheer = cheer
        self.bedtime = bedtime
        self.wardrobe = wardrobe
        self.style = style
        self.showsBubble = showsBubble
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(mode?.color ?? Toy.paper)
                .overlay { Toy.ink.opacity(bedtime == .on ? 0.35 : 0) }
                .animation(.easeInOut(duration: 0.25), value: mode)
                .animation(.easeInOut(duration: 0.8), value: bedtime)

            character
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
        .onTapGesture { react() }
        .onChange(of: mode) { _, _ in
            pop += 1
            say(nil)
        }
        .onAppear {
            if bedtime == .on, !Self.playedTonight(last: lastGoodnight, now: .now) { startGoodnight() }
            playEventIfNew()
            if invite != nil { startInvite() }
        }
        .onChange(of: invite) { _, new in
            if new != nil { startInvite() }
        }
        .onChange(of: event) { _, _ in playEventIfNew() }
        .onChange(of: bedtime) { _, new in
            if new == .on { startGoodnight() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var character: some View {
        if let mode {
            KeyframeAnimator(initialValue: 0.0, trigger: taps) { react in
                TimelineView(.animation(minimumInterval: 1 / 30, paused: paused)) { context in
                    let time = context.date.timeIntervalSinceReferenceDate
                    let life = idleLife(mode, at: context.date)
                    let motion = idleMotion(mode, life: life, time: time)
                    RunnerFigure(
                        mode: mode,
                        pose: pose(mode, life: life, time: time, react: react).wearing(Outfit(wardrobe))
                    )
                    .rotationEffect(.degrees(reduceMotion ? 0 : motion.angle), anchor: .bottom)
                    .offset(y: reduceMotion ? 0 : motion.dy)
                }
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(1, duration: 0.15)
                    LinearKeyframe(1, duration: 0.35)
                    CubicKeyframe(0, duration: 0.3)
                }
            }
            .id(mode)
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
            .keyframeAnimator(initialValue: 0.0, trigger: cheer + inviteJumps) { content, lift in
                content.offset(y: -lift)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(0, duration: 0.05)
                    SpringKeyframe(36, duration: 0.18)
                    SpringKeyframe(0, duration: 0.45, spring: .bouncy)
                }
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .black))
                Text("选一个 mode，HAKU 就上线")
                    .font(Toy.body(15, weight: .bold))
            }
            .foregroundStyle(Toy.ink)
        }
    }

    private var face: EnergyFace { EnergyFace(energy: energy) }

    /// The need RUNNER acts out: none while it is inviting, since it got up.
    private var shownNeed: CompanionNeed? { invite == nil ? need : nil }

    private var accessibilityText: String {
        let life = mode.flatMap { idleLife($0, at: .now) }
        let peeking = couchStage(at: .now) == .peeking
        return CompanionLines.accessibilityLabel(
            mode: mode,
            need: shownNeed,
            peeking: peeking,
            life: life,
            bedtime: bedtime
        )
    }

    /// The couch scrolling stage, or nil when HAKU isn't on the couch.
    private func couchStage(at date: Date) -> CouchStage? {
        guard need == .couchScroll, bedtime == .off else { return nil }
        return CouchStage.at(date, since: needSince, inviting: invite != nil)
    }

    /// What HAKU does on its own: only at home (chill), with nothing needed, awake and no event playing.
    private func idleLife(_ mode: Mode, at date: Date) -> IdleLife? {
        let time = date.timeIntervalSinceReferenceDate
        let busy = celebration(at: time) != nil || offWork(at: time) != nil
        guard mode == .chill, need == nil, invite == nil, bedtime == .off, !busy else { return nil }
        return IdleLife.at(date)
    }

    private var paused: Bool { reduceMotion || scenePhase != .active }

    private func idleMotion(_ mode: Mode, life: IdleLife?, time: TimeInterval) -> IdleMotion {
        if bedtime == .on || life == .nap { return IdleMotion.sleeping(time: time) }
        if offWork(at: time) != nil { return IdleMotion(dy: 0, angle: 0) }
        if let progress = celebration(at: time) { return IdleMotion.celebrating(progress: progress) }
        // Warming up hops like boxing day, whatever the outfit.
        if shownNeed == .couchScroll { return IdleMotion.slumped(time: time) }
        let motionMode = shownNeed == .boxingWarmup ? .boxing : mode
        return IdleMotion(mode: motionMode, time: time * face.speed)
    }

    private func pose(_ mode: Mode, life: IdleLife?, time: TimeInterval, react: Double) -> RunnerPose {
        if bedtime == .on { return bedtimePose(time: time) }
        if let progress = offWork(at: time) {
            return RunnerPose.offWork(time: time, progress: reduceMotion ? 1 : progress, face: face)
        }
        let stage = couchStage(at: Date(timeIntervalSinceReferenceDate: time))
        if reduceMotion {
            var pose = RunnerPose(face: face, need: shownNeed, life: life)
            if stage == .peeking { pose.bagLift = 0 }
            if stage == .up { pose.bagLift = 1 }
            return pose
        }
        var pose = RunnerPose(mode: mode, time: time, face: face, need: shownNeed, life: life, react: react)
        if stage == .peeking { pose.peekAtBag(time: time) }
        if stage == .up { pose.bagLift = 1 }
        if let progress = celebration(at: time) { pose.celebrate(celebrationKind, progress: CGFloat(progress)) }
        return pose
    }

    /// Progress of the celebration at `time`, 0..<1, or nil when none is playing.
    private func celebration(at time: TimeInterval) -> Double? {
        Self.progress(since: celebrationStart, at: time, duration: Self.celebrationDuration)
    }

    /// Progress of the off-work animation at `time`, 0..<1, or nil when none is playing.
    private func offWork(at time: TimeInterval) -> Double? {
        Self.progress(since: offWorkStart, at: time, duration: Self.offWorkDuration)
    }

    private static func progress(since start: Date?, at time: TimeInterval, duration: Double) -> Double? {
        guard let start = start?.timeIntervalSinceReferenceDate else { return nil }
        let progress = (time - start) / duration
        return (0..<1).contains(progress) ? progress : nil
    }

    private func bedtimePose(time: TimeInterval) -> RunnerPose {
        if reduceMotion { return RunnerPose.bedtimeStill() }
        switch style {
        case .standard:
            let start = goodnightStart?.timeIntervalSinceReferenceDate ?? -.infinity
            let goodnight = (time - start) / Self.goodnightDuration
            return RunnerPose.bedtime(time: time, goodnight: goodnight, liesDown: true)
        case .notification:
            let loop = time.truncatingRemainder(dividingBy: Self.notificationLoop) / Self.notificationLoop
            return RunnerPose.bedtime(time: time, goodnight: loop, liesDown: false)
        }
    }

    private static let goodnightDuration = 3.2
    private static let celebrationDuration = 1.6
    private static let offWorkDuration = 4.0

    /// The celebration id to play for `event`, or nil when there is none or it already played.
    nonisolated static func newCelebration(_ event: CompanionEvent?, last: String) -> String? {
        guard case .celebrate(let id, _) = event, id != last else { return nil }
        return id
    }

    /// The off-work day to play for `event`, or nil when there is none or it already played.
    nonisolated static func newOffWork(_ event: CompanionEvent?, last: String) -> String? {
        guard case .offWork(let day) = event, day != last else { return nil }
        return day
    }

    private func playEventIfNew() {
        guard bedtime == .off else { return }
        if let id = Self.newCelebration(event, last: lastCelebration), case .celebrate(_, let kind) = event {
            lastCelebration = id
            celebrationKind = kind
            celebrationStart = .now
            say(CompanionLines.celebration(kind))
        }
        if let day = Self.newOffWork(event, last: lastOffWork) {
            lastOffWork = day
            offWorkStart = .now
            say(nil)
            bubbleTask = Task {
                try? await Task.sleep(for: .seconds(Self.offWorkDuration * 0.75))
                guard !Task.isCancelled else { return }
                say("终于。")
            }
        }
    }
    private static let notificationLoop = 2.4

    /// Whether the good-night animation last played within the past 12 hours.
    nonisolated static func playedTonight(last: TimeInterval, now: Date) -> Bool {
        now.timeIntervalSinceReferenceDate - last < 12 * 60 * 60
    }

    private func startGoodnight() {
        goodnightStart = .now
        guard style == .standard else { return }
        lastGoodnight = Date.now.timeIntervalSinceReferenceDate
        bubbleTask?.cancel()
        bubbleTask = Task {
            try? await Task.sleep(for: .seconds(Self.goodnightDuration * 0.85))
            guard !Task.isCancelled else { return }
            say("该睡了")
        }
    }

    private func react() {
        pop += 1
        taps += 1
        let life = mode.flatMap { idleLife($0, at: .now) }
        let peeking = couchStage(at: .now) == .peeking
        let lines = CompanionLines.lines(for: mode, need: shownNeed, peeking: peeking, life: life)
        let candidates = lines.filter { $0 != bubble }
        say((candidates.isEmpty ? lines : candidates).randomElement())
    }

    private func startInvite() {
        guard bedtime == .off, let invite else { return }
        pop += 1
        inviteJumps += 1
        say(invite, for: 5)
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
}

private struct Squash {
    var x: CGFloat = 1
    var y: CGFloat = 1
}

/// How `CompanionView` plays.
public enum CompanionStyle: Sendable {
    /// Home screen: the full good-night animation at bedtime, then the sleepy loop.
    case standard
    /// Notification content: a short bedtime loop.
    case notification
}

// Timings match the Rive build guide.
/// Per-mode idle loop.
struct IdleMotion {
    var dy: CGFloat
    var angle: Double

    /// Slumped on the couch: tilted back, barely breathing.
    static func slumped(time t: TimeInterval) -> IdleMotion {
        IdleMotion(dy: 4 + CGFloat(sin(t * 2 * .pi / 5)), angle: -3)
    }

    /// Two happy hops over a celebration; `progress` runs 0..<1.
    static func celebrating(progress: Double) -> IdleMotion {
        IdleMotion(dy: -CGFloat(abs(sin(progress * 2 * .pi))) * 22, angle: sin(progress * 4 * .pi) * 3)
    }

    /// Slow breathing at bedtime, 4 s period.
    static func sleeping(time t: TimeInterval) -> IdleMotion {
        IdleMotion(dy: CGFloat(sin(t * 2 * .pi / 4)) * 1.5, angle: 0)
    }

    init(dy: CGFloat, angle: Double) {
        self.dy = dy
        self.angle = angle
    }

    init(mode: Mode, time t: TimeInterval) {
        switch mode {
        case .work:
            // Slow nod to the music, every 0.5 s, very small.
            dy = CGFloat(abs(sin(t * .pi / 0.5))) * 3
            angle = 0
        case .chill:
            // Sway left and right, 3 s period.
            dy = 0
            angle = sin(t * 2 * .pi / 3) * 2.5
        case .boxing:
            // Small hop every 0.6 s.
            dy = -CGFloat(abs(sin(t * .pi / 0.6))) * 8
            angle = 0
        case .money:
            // Gentle float, 4 s period.
            dy = CGFloat(sin(t * 2 * .pi / 4)) * 5
            angle = sin(t * 2 * .pi / 8) * 1
        }
    }
}

private struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Toy.body(15, weight: .bold))
            .foregroundStyle(Toy.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .toyCard(fill: Toy.card, radius: 12, shadow: 3)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(Mode.allCases) { mode in
                CompanionView(mode: mode).frame(height: 180).toyCard()
            }
            CompanionView(mode: .boxing, energy: 10).frame(height: 180).toyCard()
            CompanionView(mode: .money, energy: 85).frame(height: 180).toyCard()
            CompanionView(mode: .chill, need: .boxingWarmup).frame(height: 180).toyCard()
            CompanionView(mode: .chill, need: .couchScroll).frame(height: 180).toyCard()
            CompanionView(mode: .chill, need: .couchScroll, needSince: .now.addingTimeInterval(-45 * 60))
                .frame(height: 180)
                .toyCard()
            CompanionView(mode: .chill, need: .couchScroll, invite: "起来，下楼走 10 分钟？").frame(height: 180).toyCard()
            CompanionView(mode: .boxing, event: .celebrate(id: "preview", kind: .boxing)).frame(height: 180).toyCard()
            CompanionView(mode: .chill, event: .celebrate(id: "preview-run", kind: .running))
                .frame(height: 180)
                .toyCard()
            CompanionView(mode: .work, event: .offWork(id: "preview")).frame(height: 180).toyCard()
            CompanionView(mode: .work, bedtime: .on).frame(height: 180).toyCard()
            CompanionView(mode: .chill, bedtime: .on, style: .notification, showsBubble: false)
                .frame(height: 180)
                .toyCard()
        }
        .padding()
    }
    .background(Toy.paper)
}
