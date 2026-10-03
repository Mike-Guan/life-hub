import HubCore
import SwiftUI

extension View {
    /// Applies the weekday schedule when the app becomes active and each minute while it stays active.
    func scheduleAutoMode(_ store: ModeStore) -> some View {
        modifier(ScheduleAutoMode(store: store))
    }
}

private struct ScheduleAutoMode: ViewModifier {
    let store: ModeStore
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                store.autoSwitch(.schedule)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }
}
