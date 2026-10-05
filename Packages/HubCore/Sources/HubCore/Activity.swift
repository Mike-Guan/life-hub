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
    /// Home after a long work day: head down on the sofa arm.
    case collapsed
    /// Chill, doing nothing much: wrapped in a blanket on the couch.
    case blanket
    /// Weekday morning at home after waking up: brushing teeth.
    case morning
    /// Weekday, past 9:30 and still at home: headphones on at the door, tapping the watch.
    case timeToLeave
    /// Work or 副业, sitting for too long: HAKU twists and thumps its own back.
    case stiff
    /// Work, at the office near the end of work hours: closing the laptop, wiping the desk, then watching the clock.
    case packingUp
}

// PRD section 18. Traces fade the next day; the state logic decides which are on.
/// Something left in HAKU's world by what Mike did today.
public enum CompanionTrace: String, Codable, CaseIterable, Sendable {
    /// Boxed today: a bandage on HAKU's cheek.
    case bandage
    /// Vibe coded today: the monitor on the shelf at home is still on.
    case pcGlow
    /// Slept well: sunlight through the window at home.
    case sunlight
    /// Boxed 5 times: taped, scuffed gloves. It stays.
    case wornGloves
    /// Vibe coded 10 hours in all: a second monitor by the laptop. It stays.
    case deskMonitor
    /// Ran twice: running shoes on the floor at home. They stay.
    case runningShoes
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

    /// How far back gym days are learned from.
    public static let learnWeeks = 4
    /// In how many of those weeks a weekday needs a gym win to count as a gym day.
    public static let learnMinWeeks = 2

    // Mike 2026-10-05: gym days follow the days he actually goes, with no setting. Until a weekday
    // qualifies, the stored days stay, so the first visit doesn't stop the gym-day invite.
    /// These days with the gym days learned from the gym wins in `ledger`: each weekday with a gym win in
    /// at least `learnMinWeeks` of the last `learnWeeks` weeks, or these days when none has.
    public func learningGym(from ledger: CanLedger, now: Date, calendar: Calendar = .current) -> ActivityDays {
        let today = StateEngine.dayStart(for: now, calendar: calendar)
        var weeks: [Int: Set<Int>] = [:]
        for entry in ledger.active where entry.kind == .earned && entry.win == .gym && entry.at <= now {
            let day = StateEngine.dayStart(for: entry.at, calendar: calendar)
            let age = calendar.dateComponents([.day], from: day, to: today).day ?? .max
            guard (0..<Self.learnWeeks * 7).contains(age) else { continue }
            weeks[calendar.component(.weekday, from: day), default: []].insert(age / 7)
        }
        let learnedDays = Set(weeks.filter { $0.value.count >= Self.learnMinWeeks }.keys)
        guard !learnedDays.isEmpty else { return self }
        var learned = self
        learned.gymWeekdays = learnedDays
        return learned
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
    // PRD section 16, Mike 2026-10-05: lifting belongs to Chill. A switch to another mode at the gym stops it.
    /// The activity at `now`: running, then a gym visit (lifting only in Chill), then a gym or run day
    /// before it's done.
    /// - Parameter mode: the current mode, `nil` when none is set.
    /// - Returns: `nil` when nothing is going on.
    public static func activity(
        _ signals: ActivitySignals,
        mode: Mode?,
        days: ActivityDays = .standard,
        work: ModeRules = .standard,
        bedtime: BedtimeSchedule = .standard,
        now: Date,
        calendar: Calendar = .current
    ) -> CompanionActivity? {
        if signals.runningSince != nil { return .running }
        if signals.presence.since(.gym) != nil { return .boxingAtGym }
        if signals.presence.since(.fitness) != nil { return mode == .chill ? .gymSession : nil }
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
