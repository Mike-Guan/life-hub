import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

// Shared by the app (which starts the watch) and the monitor extension (which records the threshold).
/// Screen Time watch on the apps Mike picked, normally Bilibili and Xiaohongshu.
enum ScrollWatch {
    // Computed, not stored: these Screen Time types aren't Sendable.
    static var activity: DeviceActivityName { DeviceActivityName("lifehub.scroll") }
    static var event: DeviceActivityEvent.Name { DeviceActivityEvent.Name("lifehub.scroll.threshold") }

    private static let reachedKey = "scrollThresholdAt"
    private static let selectionKey = "scrollSelection"

    /// Minutes a day on the picked apps before RUNNER mirrors couch scrolling.
    static let minutes = 30

    /// When today's threshold was last reached, as the monitor extension recorded it.
    static var reachedAt: Date? {
        get { AppGroup.defaults.object(forKey: reachedKey) as? Date }
        set { AppGroup.defaults.set(newValue, forKey: reachedKey) }
    }

    /// The apps Mike picked, empty until he picks some.
    static var selection: FamilyActivitySelection {
        get {
            let data = AppGroup.defaults.data(forKey: selectionKey) ?? Data()
            let stored = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            return stored ?? FamilyActivitySelection()
        }
        set {
            AppGroup.defaults.set(try? JSONEncoder().encode(newValue), forKey: selectionKey)
        }
    }

    /// Watches `selection` for `minutes` a day, replacing any earlier watch. An empty selection stops it.
    /// - Throws: `DeviceActivityCenter.MonitoringError` when Screen Time refuses the schedule.
    static func start(_ selection: FamilyActivitySelection) throws {
        let center = DeviceActivityCenter()
        center.stopMonitoring([activity])
        let picked = selection.applicationTokens.count + selection.categoryTokens.count
        guard picked + selection.webDomainTokens.count > 0 else { return }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )
        // includesPastActivity: picking the apps mid-day still counts what was used earlier today.
        let threshold = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: minutes),
            includesPastActivity: true
        )
        try center.startMonitoring(activity, during: schedule, events: [event: threshold])
    }
}
