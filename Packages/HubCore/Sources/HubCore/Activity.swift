import Foundation

/// Something HAKU is doing because Mike is doing it, or is about to. Takes precedence over needs.
public enum CompanionActivity: String, Sendable {
    /// At the boxing gym: heavy-bag combos.
    case boxingAtGym
    /// At the fitness gym: lifting.
    case gymSession
    /// Running now.
    case running
    /// A gym day after work, not trained yet: the gym bag is on.
    case gymDay
    /// Run day evening, not run yet: shoe warm-up.
    case runDay
}

/// Which days are for the gym and for the weekly run. Times are minutes after local midnight.
public struct ActivityDays: Codable, Equatable, Sendable {
    /// Gym days as `Calendar` weekdays (1 is Sunday).
    public var gymWeekdays: Set<Int>
    /// Run day as a `Calendar` weekday, `nil` for none.
    public var runWeekday: Int?
    /// When the run-day warm-up starts.
    public var runStartMinute: Int

    // Mike's routine, confirmed 2026-10-04: gym Tuesday to Thursday, 5 km on Saturday evening.
    /// Gym Tuesday to Thursday, run Saturday from 17:00.
    public static let standard = ActivityDays(gymWeekdays: [3, 4, 5], runWeekday: 7, runStartMinute: 17 * 60)

    public init(gymWeekdays: Set<Int>, runWeekday: Int?, runStartMinute: Int) {
        self.gymWeekdays = gymWeekdays
        self.runWeekday = runWeekday
        self.runStartMinute = runStartMinute
    }

    static let defaultsKey = "activityDays"

    /// The days saved in `defaults`, or `.standard` when none are saved or they can't be read.
    public static func stored(in defaults: UserDefaults) -> ActivityDays {
        guard let data = defaults.data(forKey: defaultsKey) else { return .standard }
        return (try? JSONDecoder().decode(ActivityDays.self, from: data)) ?? .standard
    }

    /// Saves the days in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }
}

/// What the app knows right now that activities depend on.
public struct ActivitySignals: Equatable, Sendable {
    public var presence: PlacePresence
    /// Workouts from the last few days.
    public var workouts: [WorkoutSummary]
    /// When the current run started, `nil` when not running.
    public var runningSince: Date?

    public init(presence: PlacePresence = PlacePresence(), workouts: [WorkoutSummary] = [], runningSince: Date? = nil) {
        self.presence = presence
        self.workouts = workouts
        self.runningSince = runningSince
    }
}

/// Rules for what HAKU is doing alongside Mike.
public enum ActivityEngine {
    /// The activity at `now`: running, then a gym visit, then a gym or run day before it's done.
    /// - Returns: `nil` when nothing is going on.
    public static func activity(
        _ signals: ActivitySignals,
        days: ActivityDays = .standard,
        work: ModeRules = .standard,
        bedtime: BedtimeSchedule = .standard,
        now: Date,
        calendar: Calendar = .current
    ) -> CompanionActivity? {
        if signals.runningSince != nil { return .running }
        if signals.presence.since(.gym) != nil { return .boxingAtGym }
        if signals.presence.since(.fitness) != nil { return .gymSession }
        guard bedtime.state(at: now, calendar: calendar) == .off else { return nil }

        let today = StateEngine.dayStart(for: now, calendar: calendar)
        let weekday = calendar.component(.weekday, from: today)
        let minute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let done = signals.workouts.filter { $0.end >= today }
        if days.gymWeekdays.contains(weekday), minute >= work.workEndMinute {
            let visited = (signals.presence.left(.fitness) ?? .distantPast) >= today
            if !visited, !done.contains(where: { $0.kind != .running }) { return .gymDay }
        }
        if days.runWeekday == weekday, minute >= days.runStartMinute {
            if !done.contains(where: { $0.kind == .running }) { return .runDay }
        }
        return nil
    }
}
