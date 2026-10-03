import CompanionKit
import HubCore
import SwiftUI

struct HomeView: View {
    /// A setup problem from the app, shown with the store errors.
    var extraError: String?
    var bedtime: BedtimeSchedule = .standard
    /// What RUNNER acts out now, from the iOS app's need tracker.
    var need: NeedReading?
    /// A one-off animation for RUNNER, such as celebrating a workout.
    var event: CompanionEvent?
    /// Today's invite text while its need lasts, so RUNNER gets up and says it.
    var invite: String?
    /// Shows a settings button that calls this, when set.
    var onSettings: (() -> Void)?

    @Environment(ModeStore.self) private var store
    @Environment(EnergyStore.self) private var energy
    @State private var cheer = 0

    var body: some View {
        let reading = energy.reading()
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Header(
                    mode: store.current,
                    error: store.lastError ?? energy.lastError ?? extraError,
                    onSettings: onSettings
                )

                TimelineView(.everyMinute) { context in
                    CompanionView(
                        mode: store.current,
                        energy: reading?.value,
                        need: activeNeed(at: context.date)?.need,
                        event: event,
                        invite: activeNeed(at: context.date) == nil ? nil : invite,
                        cheer: cheer,
                        bedtime: bedtime.state(at: context.date)
                    )
                }
                .frame(height: 340)
                .toyCard()

                if let mode = store.current {
                    Text(mode.tagline)
                        .font(Toy.body(16, weight: .bold))
                        .foregroundStyle(Toy.ink)
                }

                // Why RUNNER looks the way it does: bedtime, then the need, then energy.
                TimelineView(.everyMinute) { context in
                    let state = bedtime.state(at: context.date)
                    let active = activeNeed(at: context.date)
                    if let line = NeedEngine.whyLine(need: active, energy: reading, bedtime: state) {
                        Text(line)
                            .font(Toy.body(13, weight: .bold))
                            .foregroundStyle(Toy.muted)
                    }
                }

                ModeSwitcher(current: store.current) { mode in
                    switchTo(mode)
                }

                TimelineView(.periodic(from: .now, by: 60)) { context in
                    TodayTimeline(segments: store.segments(on: context.date, now: context.date))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Toy.paper.ignoresSafeArea())
        .modeSwitchHaptic(trigger: store.current)
        .scheduleAutoMode(store)
    }

    // The tracker refreshes on open and on place events, so a need can end while the app stays open.
    private func activeNeed(at date: Date) -> NeedReading? {
        need.flatMap { $0.isActive(at: date) ? $0 : nil }
    }

    private func switchTo(_ mode: Mode) {
        let changed = withAnimation(.easeInOut(duration: 0.2)) {
            store.switchTo(mode)
        }
        // Boxing day gets a pep jump on entry.
        if changed, mode == .boxing { cheer += 1 }
    }
}

extension View {
    /// A tap on iPhone when the mode changes; nothing on Mac.
    @ViewBuilder func modeSwitchHaptic(trigger: Mode?) -> some View {
        #if os(iOS)
        sensoryFeedback(.impact(weight: .medium), trigger: trigger)
        #else
        self
        #endif
    }
}

private struct Header: View {
    let mode: Mode?
    let error: String?
    let onSettings: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(greeting)
                    .font(Toy.display(26))
                    .foregroundStyle(Toy.ink)
                Spacer()
                if let badge = AppEnvironment.badge {
                    Text(badge)
                        .font(Toy.body(11, weight: .heavy))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Toy.pink))
                        .overlay(Capsule().stroke(Toy.ink, lineWidth: 2))
                        .foregroundStyle(Toy.ink)
                }
                if let error {
                    Circle()
                        .fill(Toy.alert)
                        .overlay(Circle().stroke(Toy.ink, lineWidth: 2))
                        .frame(width: 14, height: 14)
                        .help(error)
                        .accessibilityLabel(error)
                }
                if let onSettings {
                    Button(action: onSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(Toy.body(18, weight: .heavy))
                            .foregroundStyle(Toy.ink)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("设置")
                }
            }
            Text(subtitle)
                .font(Toy.body(13, weight: .bold))
                .foregroundStyle(Toy.muted)
            if let error {
                Text(error)
                    .font(Toy.body(12))
                    .foregroundStyle(Toy.alert)
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "GOOD MORNING, MIKE"
        case 12..<18: return "GOOD AFTERNOON, MIKE"
        default: return "GOOD EVENING, MIKE"
        }
    }

    private var subtitle: String {
        let date = Date.now.formatted(.dateTime.month().day().weekday(.wide))
        return "\(date) · \(mode?.code ?? "NO MODE") MODE"
    }
}

#Preview {
    HomeView()
        .environment(ModeStore.preview())
        .environment(EnergyStore(fileURL: nil, deviceID: "preview"))
}
