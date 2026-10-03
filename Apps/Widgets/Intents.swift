import AppIntents
import HubCore

// Widget buttons only post to the inbox. The app applies the change next time it opens.
/// Switches mode from a widget button.
struct SwitchModeIntent: AppIntent {
    static let title: LocalizedStringResource = "切换模式"
    static let isDiscoverable = false

    @Parameter(title: "模式") var mode: String

    init() {}

    init(mode: Mode) {
        self.mode = mode.rawValue
    }

    func perform() async throws -> some IntentResult {
        if let mode = Mode(rawValue: mode) {
            let change = ModeChange(mode: mode, source: .manual, deviceID: HubDevice.id(defaults: AppGroup.defaults))
            try AppGroup.container.post(.mode(change))
        }
        return .result()
    }
}

/// Records Mike's own energy rating from a widget button.
struct ReportEnergyIntent: AppIntent {
    static let title: LocalizedStringResource = "记录今天电量"
    static let isDiscoverable = false

    @Parameter(title: "电量") var level: String

    init() {}

    init(level: EnergyLevel) {
        self.level = level.rawValue
    }

    func perform() async throws -> some IntentResult {
        if let level = EnergyLevel(rawValue: level) {
            let event = EnergyEvent.selfReport(level, deviceID: HubDevice.id(defaults: AppGroup.defaults))
            try AppGroup.container.post(.energy(event))
        }
        return .result()
    }
}
