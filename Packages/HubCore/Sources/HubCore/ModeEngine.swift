import Foundation

/// The rules automatic mode changes follow. Times are minutes after local midnight.
public struct ModeRules: Codable, Equatable, Sendable {
    /// Work days as `Calendar` weekdays (1 is Sunday).
    public var workdays: Set<Int>
    public var workStartMinute: Int
    public var workEndMinute: Int
    /// How long after a manual change nothing automatic may switch, except the gym.
    public var manualHold: TimeInterval
    /// How long Mike must stay at the gym before leaving restores the earlier mode.
    public var gymMinimumStay: TimeInterval

    // Defaults from Issue #4, approved by Mike on 2026-10-03.
    /// Monday to Friday 9:30 to 18:30 is work, other times chill; 2 h hold; 30 min gym stay.
    public static let standard = ModeRules(
        workdays: [2, 3, 4, 5, 6],
        workStartMinute: 9 * 60 + 30,
        workEndMinute: 18 * 60 + 30,
        manualHold: 2 * 60 * 60,
        gymMinimumStay: 30 * 60
    )

    public init(
        workdays: Set<Int>,
        workStartMinute: Int,
        workEndMinute: Int,
        manualHold: TimeInterval,
        gymMinimumStay: TimeInterval
    ) {
        self.workdays = workdays
        self.workStartMinute = workStartMinute
        self.workEndMinute = workEndMinute
        self.manualHold = manualHold
        self.gymMinimumStay = gymMinimumStay
    }
}

/// Something that may change the mode without Mike tapping.
public enum ModeTrigger: Equatable, Sendable {
    /// A periodic check against the weekday schedule.
    case schedule
    case enteredGym
    case leftGym
    case enteredOffice
}

/// An automatic change the engine wants, with the reason to show Mike.
public struct ModeDecision: Equatable, Sendable {
    public var mode: Mode
    public var source: ModeChange.Source
    public var reason: String
}

/// Rules for automatic mode changes. Manual changes always win, except arriving at the gym.
public enum ModeEngine {
    /// The mode the weekday schedule gives at `date`.
    public static func scheduledMode(at date: Date, rules: ModeRules, calendar: Calendar = .current) -> Mode {
        let weekday = calendar.component(.weekday, from: date)
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let inHours = minute >= rules.workStartMinute && minute < rules.workEndMinute
        return rules.workdays.contains(weekday) && inHours ? .work : .chill
    }

    /// The latest time at or before `date` where the schedule changes mode, within the last week.
    public static func lastScheduleChange(before date: Date, rules: ModeRules, calendar: Calendar = .current) -> Date? {
        var latest: Date?
        let today = calendar.startOfDay(for: date)
        for back in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { continue }
            guard rules.workdays.contains(calendar.component(.weekday, from: day)) else { continue }
            for minute in [rules.workStartMinute, rules.workEndMinute] {
                if let time = calendar.date(byAdding: .minute, value: minute, to: day), time <= date {
                    latest = max(latest ?? time, time)
                }
            }
        }
        return latest
    }

    /// What `trigger` should do to the mode in `log` at `now`.
    /// - Returns: the change to make, or `nil` to leave the mode alone.
    public static func decide(
        _ trigger: ModeTrigger,
        log: ModeLog,
        now: Date,
        rules: ModeRules = .standard,
        calendar: Calendar = .current
    ) -> ModeDecision? {
        let changes = log.active.filter { $0.at <= now }
        let current = changes.last
        switch trigger {
        case .enteredGym:
            guard current?.mode != .boxing else { return nil }
            return ModeDecision(mode: .boxing, source: .location, reason: "到拳馆了")

        case .leftGym:
            // Only undo our own switch: the gym entry must still be the latest change.
            guard let entry = current, isGymVisit(entry) else { return nil }
            guard now.timeIntervalSince(entry.at) >= rules.gymMinimumStay else { return nil }
            // A mode Mike picked comes back; anything automatic is re-decided by the schedule for now.
            let previous = changes.dropLast().last
            let scheduled = scheduledMode(at: now, rules: rules, calendar: calendar)
            let before = previous.map { $0.source.isManual ? $0.mode : scheduled } ?? scheduled
            guard before != .boxing else { return nil }
            return ModeDecision(mode: before, source: .location, reason: "离开拳馆，回到「\(before.title)」")

        case .enteredOffice:
            guard !isHeld(changes, now: now, rules: rules), current?.mode != .work else { return nil }
            return ModeDecision(mode: .work, source: .location, reason: "到公司了")

        case .schedule:
            guard !isHeld(changes, now: now, rules: rules) else { return nil }
            // Leaving the gym ends a visit, not the schedule.
            if let current, isGymVisit(current) { return nil }
            // The schedule acts once per period, so a later choice in the same period stays.
            let boundary = lastScheduleChange(before: now, rules: rules, calendar: calendar)
            if let current, let boundary, current.at >= boundary { return nil }
            let mode = scheduledMode(at: now, rules: rules, calendar: calendar)
            guard current?.mode != mode else { return nil }
            let reason = mode == .work ? "工作日上班时间" : "下班时间"
            return ModeDecision(mode: mode, source: .schedule, reason: reason)
        }
    }

    private static func isGymVisit(_ change: ModeChange) -> Bool {
        change.mode == .boxing && change.source == .location
    }

    private static func isHeld(_ changes: [ModeChange], now: Date, rules: ModeRules) -> Bool {
        guard let manual = changes.last(where: { $0.source.isManual }) else { return false }
        return now.timeIntervalSince(manual.at) < rules.manualHold
    }
}
