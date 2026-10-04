import CompanionKit
import HubCore
import SwiftUI

struct HomeView: View {
    /// A setup problem from the app, shown with the store errors.
    var extraError: String?
    var bedtime: BedtimeSchedule = .standard
    var rules: ModeRules = .standard
    /// What RUNNER acts out now, from the iOS app's need tracker.
    var need: NeedReading?
    /// Where Mike is and his recent workouts, for what HAKU does alongside him; `nil` when unknown.
    var activitySignals: ActivitySignals?
    /// Gym and run days.
    var activityDays: ActivityDays = .standard
    /// A one-off animation for RUNNER, such as celebrating a workout.
    var event: CompanionEvent?
    /// Today's invite text while its need lasts, so RUNNER gets up and says it.
    var invite: String?
    /// The savings card, once Mike has set a target and a balance.
    var money: MoneyCard?
    /// Shows a settings button that calls this, when set.
    var onSettings: (() -> Void)?
    /// Cans to spend; with `onShop`, shows the can count that opens the shop.
    var cans: Int?
    /// Opens the shop, when set.
    var onShop: (() -> Void)?
    /// What HAKU wears.
    var wardrobe = Wardrobe()
    /// Shows the wardrobe button on HAKU's card that calls this, when set.
    var onWardrobe: (() -> Void)?

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
                    cans: cans,
                    onShop: onShop,
                    onSettings: onSettings
                )

                TimelineView(.everyMinute) { context in
                    CompanionView(
                        mode: store.current,
                        energy: reading?.value,
                        need: activeNeed(at: context.date)?.need,
                        needSince: activeNeed(at: context.date)?.since,
                        activity: activity(at: context.date),
                        moment: store.sideHustle?.moment,
                        codingCans: codingCans(at: context.date),
                        event: event,
                        invite: activeNeed(at: context.date) == nil ? nil : invite,
                        cheer: cheer,
                        bedtime: bedtime.state(at: context.date),
                        wardrobe: wardrobe,
                        onTap: tapAction
                    )
                }
                .frame(height: 340)
                .toyCard()
                .overlay(alignment: .topTrailing) {
                    if let onWardrobe {
                        Button(action: onWardrobe) {
                            Label("衣柜", systemImage: "tshirt")
                                .font(Toy.body(15, weight: .heavy))
                                .foregroundStyle(Toy.ink)
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                                .background(Capsule().fill(Toy.card))
                                .overlay(Capsule().stroke(Toy.ink, lineWidth: Toy.outline))
                                .background(Capsule().fill(Toy.ink).offset(x: 3, y: 3))
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                    }
                }

                if let state = store.sideHustle {
                    Text("\(state.title) 中 · 点 HAKU 换状态")
                        .font(Toy.body(16, weight: .bold))
                        .foregroundStyle(Toy.ink)
                } else if let mode = store.current {
                    Text(mode.tagline)
                        .font(Toy.body(16, weight: .bold))
                        .foregroundStyle(Toy.ink)
                }

                // Why RUNNER looks the way it does: the activity, bedtime, then the need, then energy.
                TimelineView(.everyMinute) { context in
                    let state = bedtime.state(at: context.date)
                    let active = activeNeed(at: context.date)
                    let why = NeedEngine.whyLine(need: active, energy: reading, bedtime: state)
                    if let line = activity(at: context.date)?.reason ?? why {
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

                if let money {
                    money
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Toy.paper.ignoresSafeArea())
        .modeSwitchHaptic(trigger: store.current)
        .scheduleAutoMode(store, rules: rules)
    }

    // The tracker refreshes on open and on place events, so a need can end while the app stays open.
    private func activeNeed(at date: Date) -> NeedReading? {
        need.flatMap { $0.isActive(at: date) ? $0 : nil }
    }

    private func activity(at date: Date) -> CompanionActivity? {
        activitySignals.flatMap {
            ActivityEngine.activity($0, days: activityDays, work: rules, bedtime: bedtime, now: date)
        }
    }

    private func codingCans(at date: Date) -> Int {
        guard store.sideHustle == .vibeCoding, let since = store.currentSince else { return 0 }
        return SideHustle.codingCans(since: since, now: date)
    }

    // In 副业 a tap switches the state. It is manual, so it earns nothing and holds automatic switches.
    private var tapAction: (() -> Void)? {
        guard store.sideHustle != nil else { return nil }
        return {
            withAnimation(.easeInOut(duration: 0.2)) {
                _ = store.cycleSideHustle()
            }
        }
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
    let cans: Int?
    let onShop: (() -> Void)?
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
                if let cans, let onShop {
                    Button(action: onShop) {
                        CanChip(count: cans)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("商店，\(cans) 罐")
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
