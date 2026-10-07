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

/// HAKU in its current state, full screen.
struct WatchHomeView: View {
    @State private var payload = WatchPayload.read(from: AppGroup.container.watchPayloadURL)

    var body: some View {
        TimelineView(.everyMinute) { context in
            if let payload, payload.snapshot.mode != nil {
                let snapshot = payload.snapshot
                CompanionView(
                    mode: snapshot.mode,
                    energy: snapshot.energy(at: context.date)?.value,
                    need: snapshot.need(at: context.date),
                    needSince: snapshot.needSince(at: context.date),
                    traces: snapshot.traces(at: context.date),
                    vitals: snapshot.vitals ?? HakuVitals(),
                    bedtime: payload.bedtime.state(at: context.date),
                    wardrobe: payload.wardrobe,
                    style: .watch
                )
            } else {
                Text("先在 iPhone 上打开一次 Life Hub")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchReceiver.didReceive)) { _ in
            payload = WatchPayload.read(from: AppGroup.container.watchPayloadURL)
        }
    }
}
