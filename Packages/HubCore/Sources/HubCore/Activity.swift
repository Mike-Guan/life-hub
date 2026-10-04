import Foundation

/// Something HAKU is doing because Mike is doing it, or is about to. Takes precedence over needs.
public enum CompanionActivity: String, Sendable {
    /// At the boxing gym: heavy-bag combos.
    case boxingAtGym
    /// At the fitness gym: lifting.
    case gymSession
    /// Running now.
    case running
    /// A gym day after work, with no workout other than a run yet (boxing counts): the gym bag is on.
    case gymDay
    /// Run day evening, not run yet: shoe warm-up.
    case runDay

    /// Why HAKU is doing it, for the line under HAKU and the Lock Screen.
    public var reason: String {
        switch self {
        case .boxingAtGym: "你在拳馆"
        case .gymSession: "你在健身房"
        case .running: "你在跑步"
        case .gymDay: "健身日，下班了"
        case .runDay: "跑步日，傍晚了"
        }
    }
}

// PRD section 16. The state logic picks one; CompanionKit draws it.
/// A state within a mode that HAKU acts out, such as dozing off at work or vibe coding.
public enum CompanionMoment: String, Codable, CaseIterable, Sendable {
    /// Work: scrolling at work, HAKU peeks over the laptop screen.
    case slacking
    /// Work, afternoon: a yawn and a Monster.
    case drowsy
    /// Work, still there after 19:00: slumped on the desk while its soul floats off.
    case overtime
    /// Chill, gym day evening: standing at the door with the gym bag.
    case gymInvite
    /// On the way to the gym with the bag.
    case heading
    /// 副业: hoodie, `</>` on the mask, typing, cans piling up.
    case vibeCoding
    /// 副业, vibe coding for 45 minutes: silent, now and then hands over a can.
    case flow
    /// 副业, still vibe coding after 23:30: sleepy at the laptop.
    case lateCoding
    /// 副业: shooting or running the accounts, the ¥¥ mask look.
    case shooting
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
    /// Start of the hub day of the last workout other than a run, `nil` when none is known.
    public var trainedDay: Date?
    /// Start of the hub day of the last run, `nil` when none is known.
    public var ranDay: Date?
    /// When the current run started, `nil` when not running.
    public var runningSince: Date?

    public init(
        presence: PlacePresence = PlacePresence(),
        trainedDay: Date? = nil,
        ranDay: Date? = nil,
        runningSince: Date? = nil
    ) {
        self.presence = presence
        self.trainedDay = trainedDay
        self.ranDay = ranDay
        self.runningSince = runningSince
    }

    // Keeps only the day of each kind of workout, so nothing from HealthKit is copied when stored.
    /// The signals with the workout days taken from `workouts`.
    public init(
        presence: PlacePresence = PlacePresence(),
        workouts: [WorkoutSummary],
        runningSince: Date? = nil,
        calendar: Calendar = .current
    ) {
        func lastDay(_ kinds: [WorkoutSummary]) -> Date? {
            kinds.map(\.end).max().map { StateEngine.dayStart(for: $0, calendar: calendar) }
        }
        self.init(
            presence: presence,
            trainedDay: lastDay(workouts.filter { $0.kind != .running }),
            ranDay: lastDay(workouts.filter { $0.kind == .running }),
            runningSince: runningSince
        )
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
        if days.gymWeekdays.contains(weekday), minute >= work.workEndMinute {
            let visited = (signals.presence.left(.fitness) ?? .distantPast) >= today
            if !visited, (signals.trainedDay ?? .distantPast) < today { return .gymDay }
        }
        if days.runWeekday == weekday, minute >= days.runStartMinute {
            if (signals.ranDay ?? .distantPast) < today { return .runDay }
        }
        return nil
    }

    /// When activities can start on the hub day of `date` by the clock alone: the end of work on a gym
    /// day and the run-day warm-up.
    public static func startTimes(
        on date: Date,
        days: ActivityDays = .standard,
        work: ModeRules = .standard,
        calendar: Calendar = .current
    ) -> [Date] {
        let today = StateEngine.dayStart(for: date, calendar: calendar)
        let weekday = calendar.component(.weekday, from: today)
        var minutes: [Int] = []
        if days.gymWeekdays.contains(weekday) { minutes.append(work.workEndMinute) }
        if days.runWeekday == weekday { minutes.append(days.runStartMinute) }
        let midnight = calendar.startOfDay(for: today)
        return minutes.compactMap { calendar.date(byAdding: .minute, value: $0, to: midnight) }
    }
}
