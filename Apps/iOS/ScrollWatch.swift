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
    /// The second watch, limited to work hours, for scrolling at work.
    static var workActivity: DeviceActivityName { DeviceActivityName("lifehub.slack") }

    private static let reachedKey = "scrollThresholdAt"
    private static let seenKey = "scrollSeenAt"
    private static let slackReachedKey = "slackThresholdAt"
    private static let slackSeenKey = "slackSeenAt"
    private static let slackPrefix = "lifehub.slack."
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
        ladder(prefix: "lifehub.scroll.", through: lastMinutes)
    }

    /// The reports of the work-hours watch, up to the length of the work day.
    static func workEvents(for work: ModeRules) -> [Int: DeviceActivityEvent.Name] {
        ladder(prefix: slackPrefix, through: min(work.workEndMinute - work.workStartMinute, lastMinutes))
    }

    /// True for a report of the work-hours watch.
    static func isWorkEvent(_ event: DeviceActivityEvent.Name) -> Bool {
        event.rawValue.hasPrefix(slackPrefix)
    }

    private static func ladder(prefix: String, through last: Int) -> [Int: DeviceActivityEvent.Name] {
        guard last >= minutes else { return [:] }
        return Dictionary(
            uniqueKeysWithValues: stride(from: minutes, through: last, by: step).map { total in
                (total, DeviceActivityEvent.Name("\(prefix)\(total)"))
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

    /// When the current stretch of work-hours reports started.
    static var workReachedAt: Date? {
        get { AppGroup.defaults.object(forKey: slackReachedKey) as? Date }
        set { AppGroup.defaults.set(newValue, forKey: slackReachedKey) }
    }

    /// When the last work-hours report came.
    static var workSeenAt: Date? {
        get { AppGroup.defaults.object(forKey: slackSeenKey) as? Date }
        set { AppGroup.defaults.set(newValue, forKey: slackSeenKey) }
    }

    /// Records a report at `date`: a report after a quiet stretch starts a new stretch.
    static func recordReport(at date: Date, quiet: TimeInterval = NeedRules.standard.scrollQuiet) {
        if startsStretch(at: date, last: seenAt ?? reachedAt, quiet: quiet) { reachedAt = date }
        seenAt = date
    }

    /// Records a work-hours report at `date`, the same way as `recordReport`.
    static func recordWorkReport(at date: Date, quiet: TimeInterval = NeedRules.standard.scrollQuiet) {
        if startsStretch(at: date, last: workSeenAt ?? workReachedAt, quiet: quiet) { workReachedAt = date }
        workSeenAt = date
    }

    private static func startsStretch(at date: Date, last: Date?, quiet: TimeInterval) -> Bool {
        let last = last ?? .distantPast
        return date < last || date.timeIntervalSince(last) >= quiet
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

    // The work-hours watch is a second schedule, so its totals start at work start and never mix with
    // the whole-day totals of the couch watch. Weekends are filtered out by the need rules.
    /// Watches `selection` for `minutes` a day and, separately, within work hours, replacing any earlier
    /// watch. An empty selection stops both.
    /// - Parameter work: the work hours for the second watch.
    /// - Throws: `DeviceActivityCenter.MonitoringError` when Screen Time refuses a schedule.
    static func start(_ selection: FamilyActivitySelection, work: ModeRules) throws {
        let center = DeviceActivityCenter()
        center.stopMonitoring([activity, workActivity])
        let picked = selection.applicationTokens.count + selection.categoryTokens.count
        guard picked + selection.webDomainTokens.count > 0 else { return }
        let day = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )
        try center.startMonitoring(activity, during: day, events: thresholds(events, selection))
        let workEvents = workEvents(for: work)
        guard !workEvents.isEmpty else { return }
        let hours = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: work.workStartMinute / 60, minute: work.workStartMinute % 60),
            intervalEnd: DateComponents(hour: work.workEndMinute / 60, minute: work.workEndMinute % 60),
            repeats: true
        )
        try center.startMonitoring(workActivity, during: hours, events: thresholds(workEvents, selection))
    }

    // includesPastActivity: picking the apps mid-interval still counts what was used earlier in it.
    private static func thresholds(
        _ events: [Int: DeviceActivityEvent.Name],
        _ selection: FamilyActivitySelection
    ) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        events.reduce(into: [DeviceActivityEvent.Name: DeviceActivityEvent]()) { all, event in
            all[event.value] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: event.key),
                includesPastActivity: true
            )
        }
    }
}
