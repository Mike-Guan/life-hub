import HubCore
import SwiftUI

extension View {
    /// Applies the weekday schedule when the app becomes active and each minute while it stays active.
    func scheduleAutoMode(_ store: ModeStore, rules: ModeRules = .standard) -> some View {
        modifier(ScheduleAutoMode(store: store, rules: rules))
    }
}

private struct ScheduleAutoMode: ViewModifier {
    let store: ModeStore
    let rules: ModeRules
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.task(id: TaskKey(phase: scenePhase, rules: rules)) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                store.autoSwitch(.schedule, rules: rules)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }
}

// Restarts the loop when the app becomes active or the work hours change.
private struct TaskKey: Equatable {
    let phase: ScenePhase
    let rules: ModeRules
}
