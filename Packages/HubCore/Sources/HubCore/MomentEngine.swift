import Foundation

/// What the states at home depend on.
public struct HomeSignals: Equatable, Sendable {
    /// When Mike got home.
    public var since: Date
    /// Time in work mode since today's 05:00.
    public var workedToday: TimeInterval
    /// When Mike last changed the mode by hand, `nil` when never.
    public var manualAt: Date?

    public init(since: Date, workedToday: TimeInterval, manualAt: Date?) {
        self.since = since
        self.workedToday = workedToday
        self.manualAt = manualAt
    }
}

/// Picks the state within the mode HAKU acts out (PRD section 16). Same input, same output.
public enum MomentEngine {
    /// Time in work mode that makes it a long day: HAKU comes home collapsed.
    public static let longWorkDay: TimeInterval = 8 * 60 * 60
    /// How long HAKU stays collapsed after Mike gets home.
    public static let collapsedLasts: TimeInterval = 30 * 60
    /// How many minutes after work start HAKU waits at the door before giving up for the day.
    public static let leaveWaitMinutes = 90
    /// From this minute after midnight a quiet evening at home is the blanket.
    public static let blanketMinute = 21 * 60
    /// Time boxing or vibe coding today that leaves a trace.
    public static let traceAfter: TimeInterval = 30 * 60
    /// Boxing cans earned before the gloves look worn.
    public static let glovesAfter = 5
    /// Vibe coding time in all before the second monitor appears.
    public static let monitorAfter: TimeInterval = 10 * 60 * 60
    /// 5 km run cans earned before the running shoes stay out.
    public static let shoesAfter = 2

    /// The state HAKU acts out at `now`: the 副业 state, then the gym-day states, then scrolling at work,
    /// then drowsy or overtime at the office, then the states at home.
    /// - Parameters:
    ///   - activity: what HAKU does alongside Mike; only the gym bag gives way to a gym-day state.
    ///   - need: the current need.
    ///   - departing: whether Mike said he is going to the gym.
    ///   - officeSince: when Mike arrived at the office, `nil` when he isn't there.
    ///   - home: what the states at home depend on, `nil` when Mike isn't home.
    ///   - work: the work days and hours, for the weekday morning.
    /// - Returns: `nil` when HAKU shows the plain mode, activity or need.
    public static func moment(
        mode: Mode?,
        sideHustle: SideHustle?,
        activity: CompanionActivity?,
        need: CompanionNeed?,
        departing: Bool,
        officeSince: Date?,
        home: HomeSignals? = nil,
        now: Date,
        work: ModeRules = .standard,
        rules: NeedRules = .standard,
        calendar: Calendar = .current
    ) -> CompanionMoment? {
        if let sideHustle { return sideHustle.moment }
        if let gym = GymDeparture.moment(activity: activity, need: need, departing: departing) { return gym }
        if need == .slacking { return .slacking }
        if let atOffice = office(mode: mode, since: officeSince, now: now, rules: rules, calendar: calendar) {
            return atOffice
        }
        // At home the bag, the couch and the other needs come first.
        guard activity == nil, need == nil, let home else { return nil }
        return self.home(mode: mode, signals: home, now: now, work: work, calendar: calendar)
    }

    // Mike, 2026-10-05: the clock never switches to work, so a weekday morning at home is chill with
    // HAKU getting ready, then waiting at the door. A manual change today means a day off: no nudge.
    /// The state at home in chill: collapsed after a long work day, the weekday morning and the wait at the
    /// door, then the blanket in the evening.
    /// - Returns: `nil` in other modes or with nothing going on.
    public static func home(
        mode: Mode?,
        signals: HomeSignals,
        now: Date,
        work: ModeRules = .standard,
        calendar: Calendar = .current
    ) -> CompanionMoment? {
        guard mode == nil || mode == .chill, signals.since <= now else { return nil }
        if signals.workedToday >= longWorkDay, now < signals.since.addingTimeInterval(collapsedLasts) {
            return .collapsed
        }
        let minute = minuteOfDay(now, calendar: calendar)
        // PM, 2026-10-05: the door wait ends 90 minutes after work start, so a sick day isn't nagged.
        let waiting = minute < work.workStartMinute + leaveWaitMinutes
        if waiting, isWorkMorning(signals, now: now, work: work, calendar: calendar) {
            return minute < work.workStartMinute ? .morning : .timeToLeave
        }
        let lateNight = calendar.startOfDay(for: now) > StateEngine.dayStart(for: now, calendar: calendar)
        return lateNight || minute >= blanketMinute ? .blanket : nil
    }

    /// The give-up animation once HAKU stops waiting at the door: Mike was home when the wait ended and
    /// it's still work hours. Its id is the day, so it plays once a day.
    /// - Returns: `nil` when HAKU didn't wait at the door today or the wait isn't over.
    public static func stayHome(
        mode: Mode?,
        signals: HomeSignals,
        now: Date,
        work: ModeRules = .standard,
        calendar: Calendar = .current
    ) -> CompanionEvent? {
        guard mode == nil || mode == .chill, isWorkMorning(signals, now: now, work: work, calendar: calendar) else {
            return nil
        }
        let end = work.workStartMinute + leaveWaitMinutes
        let midnight = calendar.startOfDay(for: now)
        let waitEnded = calendar.date(byAdding: .minute, value: end, to: midnight) ?? midnight
        guard signals.since <= waitEnded else { return nil }
        let minute = minuteOfDay(now, calendar: calendar)
        guard minute >= end, minute < work.workEndMinute else { return nil }
        let day = Date.ISO8601FormatStyle(timeZone: calendar.timeZone).year().month().day()
        return .stayHome(id: now.formatted(day))
    }

    // From midnight to 05:00 still belongs to the day before, so it is never a work morning.
    /// Whether `now` is on a work day after 05:00 with no manual mode change since then.
    private static func isWorkMorning(
        _ signals: HomeSignals,
        now: Date,
        work: ModeRules,
        calendar: Calendar
    ) -> Bool {
        let dayStart = StateEngine.dayStart(for: now, calendar: calendar)
        let lateNight = calendar.startOfDay(for: now) > dayStart
        let dayOff = signals.manualAt.map { $0 >= dayStart } ?? false
        return work.workdays.contains(calendar.component(.weekday, from: now)) && !lateNight && !dayOff
    }

    private static func minuteOfDay(_ date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// When the states at home start or end on the day of `now`, for widget timelines.
    public static func homeTimes(
        since: Date?,
        now: Date,
        work: ModeRules = .standard,
        calendar: Calendar = .current
    ) -> [Date] {
        guard let since else { return [] }
        let midnight = calendar.startOfDay(for: now)
        let minute = { (value: Int) in calendar.date(byAdding: .minute, value: value, to: midnight) ?? midnight }
        let minutes = [work.workStartMinute, work.workStartMinute + leaveWaitMinutes, blanketMinute]
        return [since.addingTimeInterval(collapsedLasts)] + minutes.map(minute)
    }

    /// Time in work mode in `log` from today's 05:00 to `now`.
    public static func workedToday(_ log: ModeLog, now: Date, calendar: Calendar = .current) -> TimeInterval {
        log.time(from: StateEngine.dayStart(for: now, calendar: calendar), to: now) { $0.mode == .work }
    }

    // PRD section 18. Traces are only a look: they never earn cans. They fade at the next 05:00.
    /// What today left in HAKU's world: the bandage after boxing, the monitor after vibe coding and the
    /// sunlight after a full night's sleep.
    /// - Parameters:
    ///   - workouts: recent workouts from the Health app.
    ///   - energy: today's energy level.
    public static func traces(
        log: ModeLog,
        workouts: [WorkoutSummary],
        energy: EnergyLevel?,
        now: Date,
        calendar: Calendar = .current
    ) -> Set<CompanionTrace> {
        let dayStart = StateEngine.dayStart(for: now, calendar: calendar)
        let boxed =
            workouts.contains { $0.kind == .boxing && $0.end >= dayStart && $0.end <= now }
            || log.time(from: dayStart, to: now) { $0.mode == .boxing } >= traceAfter
        let coded = log.time(from: dayStart, to: now) { $0.sideHustle == .vibeCoding } >= traceAfter
        var traces: Set<CompanionTrace> = []
        if boxed { traces.insert(.bandage) }
        if coded { traces.insert(.pcGlow) }
        if energy == .full { traces.insert(.sunlight) }
        return traces
    }

    // PRD section 19: these build up over weeks and never fade, unlike today's traces.
    /// The traces that stay once Mike has done enough of something, counted from earned cans and the mode log.
    public static func lastingTraces(log: ModeLog, ledger: CanLedger, now: Date) -> Set<CompanionTrace> {
        var traces: Set<CompanionTrace> = []
        if ledger.count(.boxing) >= glovesAfter { traces.insert(.wornGloves) }
        if ledger.count(.run5k) >= shoesAfter { traces.insert(.runningShoes) }
        if log.time(from: .distantPast, to: now, where: { $0.sideHustle == .vibeCoding }) >= monitorAfter {
            traces.insert(.deskMonitor)
        }
        return traces
    }

    // One drowsy spell a day: from 3 hours after arriving or 14:00, whichever comes first.
    /// Drowsy or overtime while in work mode at the office, else `nil`.
    public static func office(
        mode: Mode?,
        since: Date?,
        now: Date,
        rules: NeedRules = .standard,
        calendar: Calendar = .current
    ) -> CompanionMoment? {
        guard mode == .work, let since, since <= now else { return nil }
        let midnight = calendar.startOfDay(for: now)
        func time(_ minute: Int) -> Date {
            calendar.date(byAdding: .minute, value: minute, to: midnight) ?? midnight
        }
        if now >= time(rules.overtimeMinute) { return .overtime }
        let start = min(time(rules.drowsyStartMinute), since.addingTimeInterval(rules.drowsyAfterArrival))
        return now >= start && now < start.addingTimeInterval(rules.drowsyLasts) ? .drowsy : nil
    }

    /// When the office states start or end on the day of `now`, for widget timelines.
    public static func officeTimes(
        since: Date?,
        now: Date,
        rules: NeedRules = .standard,
        calendar: Calendar = .current
    ) -> [Date] {
        guard let since else { return [] }
        let midnight = calendar.startOfDay(for: now)
        let minute = { (value: Int) in calendar.date(byAdding: .minute, value: value, to: midnight) ?? midnight }
        let start = min(minute(rules.drowsyStartMinute), since.addingTimeInterval(rules.drowsyAfterArrival))
        return [start, start.addingTimeInterval(rules.drowsyLasts), minute(rules.overtimeMinute)]
    }
}
