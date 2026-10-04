import AppIntents
import HubCore
import WidgetKit

// Mike adds this filter to an iOS Focus named "编程" and turns the switch on. iOS calls `perform`
// when that Focus starts and again, with the default values, when it ends; the default does nothing.
/// Switches to 副业 · vibe coding when a Focus with this filter starts.
struct SideHustleFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "副业 · vibe coding"
    static let description: IntentDescription? = "这个专注模式开着时，切到副业 · vibe coding。手动切过模式的 2 小时内不切。"

    @Parameter(title: "切到副业", default: false) var switchesMode: Bool

    @Dependency private var store: ModeStore

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: switchesMode ? "切到副业 · vibe coding" : "不切换")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if switchesMode, store.autoSwitch(.codingFocus, rules: .stored(in: AppGroup.defaults)) != nil {
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}
