import HubCore
import SwiftUI

@main
struct LifeHubMacApp: App {
    @State private var store = ModeStore.live()

    var body: some Scene {
        WindowGroup("Life Hub") {
            HomeView()
                .environment(store)
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
