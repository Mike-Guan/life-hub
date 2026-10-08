import CompanionKit
import HubCore
import SwiftUI

// Issue #160. The watch app only shows HAKU as the iPhone last saw it; it changes nothing.
@main
struct LifeHubWatchApp: App {
    init() {
        // Started at launch, so a background launch for a complication transfer gets its data.
        WatchReceiver.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
        }
        .backgroundTask(.watchConnectivity) {
            await WatchReceiver.shared.waitForPendingContent()
        }
    }
}

/// Two pages from the approved C layout: the character full screen, then today's mode, energy and line.
struct WatchHomeView: View {
    @State private var payload = WatchPayload.read(from: AppGroup.container.watchPayloadURL)

    @State private var failure: String?

    var body: some View {
        TimelineView(.everyMinute) { context in
            if let payload, let mode = payload.snapshot.mode {
                TabView {
                    companionPage(payload, mode: mode, at: context.date)
                    TodayPage(payload: payload, mode: mode, date: context.date)
                }
                .tabViewStyle(.verticalPage)
            } else {
                Text(failure ?? "先在 iPhone 上打开一次 Life Hub")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchReceiver.didReceive)) { _ in
            payload = WatchPayload.read(from: AppGroup.container.watchPayloadURL)
            failure = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchReceiver.didFail)) { note in
            failure = note.object as? String
        }
    }

    // Used by scripts/recordings.sh for promo stills. Debug builds only.
    /// Launch argument `-clean-frame` hides the mode chip, so only the character shows.
    private static var cleanFrame: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-clean-frame")
        #else
        false
        #endif
    }

    /// Page 1: the mode's color to every edge, the character from the chest up, and a small mode chip.
    private func companionPage(_ payload: WatchPayload, mode: Mode, at date: Date) -> some View {
        let snapshot = payload.snapshot
        let scene = payload.scenes.scene(at: date)
        return Group {
            if payload.persona == .kuro {
                KuroView(
                    look: KuroLook(mode: mode),
                    energy: snapshot.energy(at: date)?.value,
                    bedtime: payload.bedtime.state(at: date),
                    need: snapshot.need(at: date),
                    activity: scene?.activity,
                    moment: scene?.moment,
                    overtimeUntil: scene?.overtimeUntil,
                    style: .watch,
                    wearing: Set(payload.wardrobe.equipped.values),
                    event: payload.event ?? scene?.event
                )
            } else {
                CompanionView(
                    mode: mode,
                    energy: snapshot.energy(at: date)?.value,
                    need: snapshot.need(at: date),
                    needSince: snapshot.needSince(at: date),
                    activity: scene?.activity,
                    moment: scene?.moment,
                    codingCans: scene?.codingCans ?? 0,
                    traces: snapshot.traces(at: date),
                    vitals: snapshot.vitals ?? HakuVitals(),
                    // Same order as the iPhone home card: a one-off from the iPhone, then the time's.
                    event: payload.event ?? scene?.event,
                    daily: scene?.daily,
                    walking: scene?.walking,
                    commute: scene?.commute,
                    bath: scene?.bath ?? false,
                    invite: scene?.invite,
                    bedtime: payload.bedtime.state(at: date),
                    wardrobe: payload.wardrobe,
                    style: .watch
                )
            }
        }
        .clipped()
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4) {
                if !Self.cleanFrame {
                    ModeChip(mode: mode, persona: payload.persona, since: snapshot.since)
                }
                if let failure {
                    Text(failure).font(.caption2).foregroundStyle(Toy.ink).lineLimit(2)
                }
            }
            .padding(.leading, 4)
        }
    }
}

/// The mode and how long it has run, in a small white pill.
private struct ModeChip: View {
    let mode: Mode
    let persona: Persona
    let since: Date?

    var body: some View {
        Group {
            if let since {
                Text("\(mode.title(for: persona)) · \(Text(since, style: .relative))")
            } else {
                Text(mode.title(for: persona))
            }
        }
        .font(Toy.body(12, weight: .heavy))
        .foregroundStyle(Toy.ink)
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Capsule().fill(Toy.card))
        .overlay(Capsule().stroke(Toy.ink, lineWidth: 2))
    }
}

/// Page 2: what the iPhone already worked out for today. It holds still, since it is for reading.
private struct TodayPage: View {
    let payload: WatchPayload
    let mode: Mode
    let date: Date

    var body: some View {
        let snapshot = payload.snapshot
        VStack(alignment: .leading, spacing: 8) {
            row("模式") {
                if let since = snapshot.since {
                    Text("\(mode.title(for: payload.persona)) · \(Text(since, style: .relative))")
                } else {
                    Text(mode.title(for: payload.persona))
                }
            }
            if let energy = snapshot.energy(at: date) {
                row("电量") {
                    HStack(spacing: 8) {
                        Text(energy.title)
                        EnergyBars(filled: Self.bars(energy))
                    }
                }
            }
            if let line = snapshot.line(at: date) {
                row(payload.persona == .kuro ? "KURO 说" : "HAKU 说") {
                    Text(line).lineLimit(3).minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20).fill(Toy.card))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Toy.ink, lineWidth: Toy.outline))
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(mode.color(for: payload.persona).ignoresSafeArea())
    }

    private func row<Value: View>(_ title: String, @ViewBuilder value: () -> Value) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(Toy.body(11, weight: .bold)).foregroundStyle(Toy.muted)
            value().font(Toy.body(15, weight: .heavy)).foregroundStyle(Toy.ink)
        }
    }

    /// How many of the five bars an energy level fills.
    static func bars(_ energy: EnergyLevel) -> Int {
        switch energy {
        case .low: 1
        case .okay: 3
        case .full: 5
        }
    }
}

/// Five outlined bars, the first `filled` of them solid.
private struct EnergyBars: View {
    let filled: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < filled ? Toy.ink : .clear)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Toy.ink, lineWidth: 1.5))
                    .frame(width: 7, height: 14)
            }
        }
    }
}
