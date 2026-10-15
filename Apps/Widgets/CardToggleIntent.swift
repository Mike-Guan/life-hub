import AppIntents
import HubCore
import WidgetKit

/// A card a control can switch to and back: 副业 or the identity card.
enum ControlCard: String, AppEnum {
    case money
    case identity

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "模式卡" }
    static var caseDisplayRepresentations: [ControlCard: DisplayRepresentation] {
        [.money: "副业", .identity: "身份卡"]
    }

    /// The mode the card switches to.
    var mode: Mode { self == .money ? .money : .boxing }
}

// Issue #481: built into the app too, so a Live Activity intent runs in the app's process.
/// Switches to a card, or back to the mode before it.
struct CardToggleIntent: SetValueIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "进入或退出模式卡"
    static let isDiscoverable = false

    @Parameter(title: "模式卡") var card: ControlCard
    @Parameter(title: "进入") var value: Bool

    init() {}

    init(card: ControlCard) {
        self.card = card
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let persona = Persona.stored(in: AppGroup.defaults)
        guard ModeCards.current(in: AppGroup.defaults, persona: persona).modes.contains(card.mode) else {
            return .result()
        }
        let log = ModeLog.read(from: AppGroup.container.modeLogURL)
        let mode = value ? card.mode : (log.latest(other: card.mode) ?? .chill)
        let change = ModeChange(mode: mode, source: .manual, deviceID: HubDevice.id(defaults: AppGroup.defaults))
        try AppGroup.container.post(.mode(change))
        WidgetTaps.apply?()
        ControlCenter.shared.reloadAllControls()
        return .result()
    }
}
