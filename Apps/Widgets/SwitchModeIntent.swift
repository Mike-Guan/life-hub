import AppIntents
import HubCore
import WidgetKit

// Issue #481: a Live Activity intent runs in the app's process when the app has it too, so the app applies
// the change at once. Built into both the app and the widget extension.
/// Switches mode from a widget button.
struct SwitchModeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "切换模式"
    static let isDiscoverable = false

    @Parameter(title: "模式") var mode: String

    init() {}

    init(mode: Mode) {
        self.mode = mode.rawValue
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let mode = Mode(rawValue: mode) {
            let change = ModeChange(mode: mode, source: .manual, deviceID: HubDevice.id(defaults: AppGroup.defaults))
            try AppGroup.container.post(.mode(change))
        }
        WidgetTaps.apply?()
        return .result()
    }
}

// The widget extension leaves it unset; there the change waits in the inbox until the app opens.
/// What the app does right after a widget button posts a change.
@MainActor
enum WidgetTaps {
    /// Applies the posted changes and updates the watch, the widgets and the notices.
    static var apply: (@MainActor () -> Void)?
}
