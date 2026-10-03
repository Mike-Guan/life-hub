import HubCore
import SwiftUI

// Draws RUNNER from vector parts with SwiftUI motion. When `runner.riv` exists this view
// switches to Rive internally; callers keep passing `mode`, `energy` and `cheer`.
/// RUNNER, reacting to the current mode and energy.
public struct CompanionView: View {
    let mode: Mode?
    /// Energy 0-100, or nil when unknown. Below 30 RUNNER looks tired.
    let energy: Double?
    /// Increment to play the cheer jump.
    let cheer: Int
    /// `.on` turns RUNNER sleepy; each change to `.on` plays the good-night animation once.
    let bedtime: Bedtime
    let style: CompanionStyle
    let showsBubble: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var pop = 0
    @State private var taps = 0
    @State private var goodnightStart: Date?
    @State private var bubble: String?
    @State private var bubbleTask: Task<Void, Never>?

    public init(
        mode: Mode?,
        energy: Double? = nil,
        cheer: Int = 0,
        bedtime: Bedtime = .off,
        style: CompanionStyle = .standard,
        showsBubble: Bool = true
    ) {
        self.mode = mode
        self.energy = energy
        self.cheer = cheer
        self.bedtime = bedtime
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
            if bedtime == .on { startGoodnight() }
        }
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
                    let motion = idleMotion(mode, time: time)
                    RunnerFigure(mode: mode, pose: pose(mode, time: time, react: react))
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
            .keyframeAnimator(initialValue: 0.0, trigger: cheer) { content, lift in
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
                Text("选一个 mode，RUNNER 就上线")
                    .font(Toy.body(15, weight: .bold))
            }
            .foregroundStyle(Toy.ink)
        }
    }

    private var tired: Bool { RunnerPose.isTired(energy) }

    private var accessibilityText: String {
        if bedtime == .on { return "RUNNER，困了" }
        return mode.map { "RUNNER，\($0.title)" } ?? "RUNNER"
    }

    private var paused: Bool { reduceMotion || scenePhase == .background }

    private func idleMotion(_ mode: Mode, time: TimeInterval) -> IdleMotion {
        if bedtime == .on { return IdleMotion.sleeping(time: time) }
        return IdleMotion(mode: mode, time: time * (tired ? 0.6 : 1))
    }

    private func pose(_ mode: Mode, time: TimeInterval, react: Double) -> RunnerPose {
        if bedtime == .on { return bedtimePose(time: time) }
        if reduceMotion { return RunnerPose(tired: tired) }
        return RunnerPose(mode: mode, time: time, tired: tired, react: react)
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
    private static let notificationLoop = 2.4

    private func startGoodnight() {
        goodnightStart = .now
        guard style == .standard else { return }
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
        let lines = CompanionLines.lines(for: mode)
        let candidates = lines.filter { $0 != bubble }
        say((candidates.isEmpty ? lines : candidates).randomElement())
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
            CompanionView(mode: .work, bedtime: .on).frame(height: 180).toyCard()
            CompanionView(mode: .chill, bedtime: .on, style: .notification, showsBubble: false)
                .frame(height: 180)
                .toyCard()
        }
        .padding()
    }
    .background(Toy.paper)
}
