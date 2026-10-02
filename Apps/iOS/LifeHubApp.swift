import HubCore
import SwiftUI

@main
struct LifeHubApp: App {
    @State private var store = ModeStore.live()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
        }
    }
}
