import DeviceActivity
import FamilyControls
import Foundation
import HubCore
import ManagedSettings

// Shared by the app (which starts the watch) and the monitor extension (which records the threshold).
/// Screen Time watch on the apps Mike picked, normally Bilibili and Xiaohongshu.
enum ScrollWatch {
    // Computed, not stored: these Screen Time types aren't Sendable.
    static var activity: DeviceActivityName { DeviceActivityName("lifehub.scroll") }

    private static let reachedKey = "scrollThresholdAt"
    private static let seenKey = "scrollSeenAt"
    private static let selectionKey = "scrollSelection"

    /// Minutes a day on the picked apps before RUNNER mirrors couch scrolling.
    static let minutes = 30
    /// After `minutes`, Screen Time reports again after each this many more minutes of use.
    static let step = 10
    /// The last report, in minutes of use a day.
    static let lastMinutes = 6 * 60

    // Screen Time only says when a total is reached, never when use stops. A report every `step`
    // minutes of use tells the app that Mike is still scrolling; no report for a while means he stopped.
    /// One event per report, named by its total in minutes.
    static var events: [Int: DeviceActivityEvent.Name] {
        Dictionary(
            uniqueKeysWithValues: stride(from: minutes, through: lastMinutes, by: step).map { total in
                (total, DeviceActivityEvent.Name("lifehub.scroll.\(total)"))
            })
    }

    /// When the current stretch of reports started, as the monitor extension recorded it.
    static var reachedAt: Date? {
        get { AppGroup.defaults.object(forKey: reachedKey) as? Date }
        set { AppGroup.defaults.set(newValue, forKey: reachedKey) }
    }

    /// When the last report came.
    static var seenAt: Date? {
        get { AppGroup.defaults.object(forKey: seenKey) as? Date }
        set { AppGroup.defaults.set(newValue, forKey: seenKey) }
    }

    /// Records a report at `date`: a report after a quiet stretch starts a new stretch.
    static func recordReport(at date: Date, quiet: TimeInterval = NeedRules.standard.scrollQuiet) {
        let last = seenAt ?? reachedAt ?? .distantPast
        if date < last || date.timeIntervalSince(last) >= quiet {
            reachedAt = date
        }
        seenAt = date
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

    /// True when Mike has picked at least one app, category or site.
    static var hasSelection: Bool {
        let picked = selection
        return picked.applicationTokens.count + picked.categoryTokens.count + picked.webDomainTokens.count > 0
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
        let thresholds = events.reduce(into: [DeviceActivityEvent.Name: DeviceActivityEvent]()) { all, event in
            all[event.value] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: event.key),
                includesPastActivity: true
            )
        }
        try center.startMonitoring(activity, during: schedule, events: thresholds)
    }
}
