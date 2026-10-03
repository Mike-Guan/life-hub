import HubCore
import SwiftUI

@main
struct LifeHubMacApp: App {
    @State private var store = ModeStore.live()
    @State private var energy = EnergyStore.live()

    var body: some Scene {
        WindowGroup("Life Hub") {
            Group {
                if let mode = ScreenshotMode.mode {
                    ScreenshotHome(mode: mode)
                } else {
                    HomeView()
                        .environment(store)
                        .environment(energy)
                }
            }
            .frame(minWidth: 440, minHeight: 720)
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarPanel()
                .environment(store)
        } label: {
            Image(systemName: store.current?.symbol ?? "circle.dashed")
        }
        .menuBarExtraStyle(.window)
    }
}
