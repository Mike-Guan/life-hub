import Foundation

/// What RUNNER acts out when Mike seems to need something. At most one at a time.
public enum CompanionNeed: String, Codable, CaseIterable, Sendable {
    /// Lying at home scrolling Bilibili or Xiaohongshu.
    case couchScroll
    /// Boxing day and not at the gym yet.
    case boxingWarmup
    /// Gym day evening, still at home and not trained: HAKU waits at the door with the bag.
    case gymDay
    /// Scrolling the picked apps for a while during work hours: HAKU peeks over the laptop.
    case slacking
}

/// A short animation RUNNER plays once, then goes back to its usual look.
public enum CompanionEvent: Equatable, Sendable {
    /// Celebrate a workout of `kind`; `id` is the workout's id, so each one plays once.
    case celebrate(id: String, kind: WorkoutSummary.Kind)
    /// The off-work animation after the off-work notification is tapped; `id` is the day, "yyyy-MM-dd".
    case offWork(id: String)
    /// Unboxing a new wardrobe item; `id` is the ledger entry's id, so each one plays once, and
    /// `item` is the `ShopItem` id.
    case unlock(id: String, item: String)
}

/// A workout from the Health app, reduced to what the hub uses.
public struct WorkoutSummary: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case boxing
        case running
        case strength
        case other
    }

    /// The Health app's id for the workout, so each one is celebrated once.
    public var id: String
    public var kind: Kind
    public var start: Date
    public var end: Date
    /// Distance in meters, `nil` when the workout has none.
    public var meters: Double?

    public init(id: String, kind: Kind, start: Date, end: Date, meters: Double? = nil) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.meters = meters
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// The rules for needs, invites and celebrations. Times are minutes after local midnight.
public struct NeedRules: Codable, Equatable, Sendable {
    /// Before this, being still at home doesn't count as couch scrolling.
    public var eveningStartMinute: Int
    /// How long Mike must be still at home before the fallback says couch scrolling.
    public var stillFor: TimeInterval
    /// How long couch scrolling lasts after the last Screen Time report.
    public var scrollQuiet: TimeInterval
    /// Boxing day as a `Calendar` weekday (1 is Sunday).
    public var boxingWeekday: Int
    /// When boxing warm-up starts on boxing day.
    public var boxingWarmupStartMinute: Int
    /// When boxing warm-up gives up on boxing day.
    public var boxingWarmupEndMinute: Int
    /// Until this, boxing warm-up outranks couch scrolling on boxing day.
    public var boxingFirstUntilMinute: Int
    /// When boxing class starts on boxing day; the countdown runs to it.
    public var boxingStartMinute: Int
    /// How long couch scrolling lasts before the invite.
    public var couchInviteAfter: TimeInterval
    /// How long boxing warm-up lasts before the invite.
    public var boxingInviteAfter: TimeInterval
    /// No invite within this long of the last one.
    public var inviteCooldown: TimeInterval
    /// How long after a workout ends RUNNER still celebrates it.
    public var celebrateWithin: TimeInterval
    /// A run at least this long, in meters, is celebrated.
    public var celebrateRunMeters: Double
    /// A boxing workout at least this long is celebrated.
    public var celebrateBoxing: TimeInterval
    /// A strength workout at least this long is celebrated.
    public var celebrateStrength: TimeInterval
    /// When HAKU starts waiting at the door on gym days.
    public var gymInviteStartMinute: Int
    /// When HAKU gives up waiting at the door on gym days.
    public var gymInviteEndMinute: Int
    /// How long HAKU waits at the door before the invite.
    public var gymInviteAfter: TimeInterval
    /// When HAKU gets drowsy at the office at the latest.
    public var drowsyStartMinute: Int
    /// After this long at the office HAKU gets drowsy, if that comes before `drowsyStartMinute`.
    public var drowsyAfterArrival: TimeInterval
    /// How long the drowsy spell lasts.
    public var drowsyLasts: TimeInterval
    /// From this time, still at the office is overtime.
    public var overtimeMinute: Int

    // Defaults from Issue #23 (Mike's smaller first version, 2026-10-03). Starting guesses.
    /// Couch after 19:00 and 60 still minutes, or until 20 min after the last Screen Time report; boxing Sunday
    /// 9:00 to 12:00 with class at 10:00; invites after 60 / 30 min.
    public static let standard = NeedRules(
        eveningStartMinute: 19 * 60,
        stillFor: 60 * 60,
        scrollQuiet: 20 * 60,
        boxingWeekday: 1,
        boxingWarmupStartMinute: 9 * 60,
        boxingWarmupEndMinute: 12 * 60,
        boxingFirstUntilMinute: 10 * 60 + 30,
        boxingStartMinute: 10 * 60,
        couchInviteAfter: 60 * 60,
        boxingInviteAfter: 30 * 60,
        inviteCooldown: 3 * 60 * 60,
        celebrateWithin: 3 * 60 * 60,
        celebrateRunMeters: 5000,
        celebrateBoxing: 30 * 60
    )

    public init(
        eveningStartMinute: Int,
        stillFor: TimeInterval,
        scrollQuiet: TimeInterval,
        boxingWeekday: Int,
        boxingWarmupStartMinute: Int,
        boxingWarmupEndMinute: Int,
        boxingFirstUntilMinute: Int,
        boxingStartMinute: Int,
        couchInviteAfter: TimeInterval,
        boxingInviteAfter: TimeInterval,
        inviteCooldown: TimeInterval,
        celebrateWithin: TimeInterval,
        celebrateRunMeters: Double,
        celebrateBoxing: TimeInterval,
        celebrateStrength: TimeInterval = 20 * 60,
        gymInviteStartMinute: Int = 19 * 60 + 30,
        gymInviteEndMinute: Int = 20 * 60 + 30,
        gymInviteAfter: TimeInterval = 30 * 60,
        drowsyStartMinute: Int = 14 * 60,
        drowsyAfterArrival: TimeInterval = 3 * 60 * 60,
        drowsyLasts: TimeInterval = 2 * 60 * 60,
        overtimeMinute: Int = 19 * 60
    ) {
        self.eveningStartMinute = eveningStartMinute
        self.stillFor = stillFor
        self.scrollQuiet = scrollQuiet
        self.boxingWeekday = boxingWeekday
        self.boxingWarmupStartMinute = boxingWarmupStartMinute
        self.boxingWarmupEndMinute = boxingWarmupEndMinute
        self.boxingFirstUntilMinute = boxingFirstUntilMinute
        self.boxingStartMinute = boxingStartMinute
        self.couchInviteAfter = couchInviteAfter
        self.boxingInviteAfter = boxingInviteAfter
        self.inviteCooldown = inviteCooldown
        self.celebrateWithin = celebrateWithin
        self.celebrateRunMeters = celebrateRunMeters
        self.celebrateBoxing = celebrateBoxing
        self.celebrateStrength = celebrateStrength
        self.gymInviteStartMinute = gymInviteStartMinute
        self.gymInviteEndMinute = gymInviteEndMinute
        self.gymInviteAfter = gymInviteAfter
        self.drowsyStartMinute = drowsyStartMinute
        self.drowsyAfterArrival = drowsyAfterArrival
        self.drowsyLasts = drowsyLasts
        self.overtimeMinute = overtimeMinute
    }
}

/// What the app knows right now that needs depend on. Unknown signals are `nil` or `false`.
public struct NeedSignals: Equatable, Sendable {
    /// When the current stretch of Screen Time reports on Bilibili and Xiaohongshu started.
    public var scrollThresholdAt: Date?
    /// When the last Screen Time report came, `nil` when it is `scrollThresholdAt`.
    public var scrollSeenAt: Date?
    /// When Mike last changed mode by hand; a need from before it is over.
    public var manualSince: Date?
    /// When Mike last arrived home, `nil` when he isn't home or it is unknown.
    public var atHomeSince: Date?
    /// True when Mike has set his home, so not being home is known rather than unknown.
    public var homeKnown: Bool
    /// Start of the current stretch without walking, `nil` when unknown.
    public var stillSince: Date?
    /// True while Mike is at the gym.
    public var atGym: Bool
    /// Workouts from the last few days.
    public var workouts: [WorkoutSummary]
    /// When Mike was last at the fitness gym: his arrival while there, else when he left.
    public var fitnessSeenAt: Date?
    /// True while Mike is on his way to the gym after saying he is going.
    public var departing: Bool
    /// When the current stretch of work-hours Screen Time reports started.
    public var slackThresholdAt: Date?
    /// When the last work-hours report came, `nil` when it is `slackThresholdAt`.
    public var slackSeenAt: Date?

    public init(
        scrollThresholdAt: Date? = nil,
        scrollSeenAt: Date? = nil,
        manualSince: Date? = nil,
        atHomeSince: Date? = nil,
        homeKnown: Bool = false,
        stillSince: Date? = nil,
        atGym: Bool = false,
        workouts: [WorkoutSummary] = [],
        fitnessSeenAt: Date? = nil,
        departing: Bool = false,
        slackThresholdAt: Date? = nil,
        slackSeenAt: Date? = nil
    ) {
        self.scrollThresholdAt = scrollThresholdAt
        self.scrollSeenAt = scrollSeenAt
        self.manualSince = manualSince
        self.atHomeSince = atHomeSince
        self.homeKnown = homeKnown
        self.stillSince = stillSince
        self.atGym = atGym
        self.workouts = workouts
        self.fitnessSeenAt = fitnessSeenAt
        self.departing = departing
        self.slackThresholdAt = slackThresholdAt
        self.slackSeenAt = slackSeenAt
    }
}

/// The need RUNNER shows, since when, and why.
public struct NeedReading: Equatable, Sendable {
    public var need: CompanionNeed
    /// When the need started; invites wait on this.
    public var since: Date
    /// Plain sentences, shown to Mike as the reason.
    public var reasons: [String]
    /// When the need ends at the latest, `nil` when only a new signal can end it.
    public var until: Date?

    /// True until `until`, or always when there is no end time.
    public func isActive(at date: Date) -> Bool {
        until.map { date < $0 } ?? true
    }
}

/// A need that depends only on the clock, so widgets can show it without the app running.
public struct ScheduledNeed: Codable, Equatable, Sendable {
    public var need: CompanionNeed
    public var from: Date
    public var until: Date
    /// The "why" line while it lasts.
    public var line: String

    public init(need: CompanionNeed, from: Date, until: Date, line: String) {
        self.need = need
        self.from = from
        self.until = until
        self.line = line
    }

    /// True from `from` until `until`.
    public func contains(_ date: Date) -> Bool {
        date >= from && date < until
    }
}

/// Rule-based needs, invites and celebrations. Same input, same output; every need says why.
public enum NeedEngine {
    /// How long couch scrolling lasts before HAKU starts peeking at the gym bag.
    public static let couchPeekAfter: TimeInterval = 30 * 60

    /// The need at `now`, or `nil` when there is none. A gym-day evening at home comes first, then scrolling
    /// in work hours, then couch scrolling, except on a boxing morning, when scrolling at home is exactly what
    /// boxing warm-up is about.
    /// - Parameters:
    ///   - days: which days are gym days.
    ///   - work: the work days and hours, for scrolling at work.
    public static func need(
        _ signals: NeedSignals,
        now: Date,
        rules: NeedRules = .standard,
        days: ActivityDays = .standard,
        work: ModeRules = .standard,
        calendar: Calendar = .current
    ) -> NeedReading? {
        if let gym = gymDay(signals, now: now, rules: rules, days: days, calendar: calendar) { return gym }
        if let slacking = slacking(signals, now: now, rules: rules, work: work, calendar: calendar) {
            return slacking
        }
        let boxing = boxingWarmup(signals, now: now, rules: rules, calendar: calendar)
        if boxing != nil, now < time(rules.boxingFirstUntilMinute, on: now, calendar: calendar) {
            return boxing
        }
        return couchScroll(signals, now: now, rules: rules, calendar: calendar) ?? boxing
    }

    /// The next boxing warm-up that starts after `now`, within a week.
    public static func nextScheduled(
        after now: Date,
        rules: NeedRules = .standard,
        calendar: Calendar = .current
    ) -> ScheduledNeed? {
        let midnight = calendar.startOfDay(for: now)
        let days = (0...7).compactMap { calendar.date(byAdding: .day, value: $0, to: midnight) }
        for day in days where calendar.component(.weekday, from: day) == rules.boxingWeekday {
            let start = time(rules.boxingWarmupStartMinute, on: day, calendar: calendar)
            let end = time(rules.boxingWarmupEndMinute, on: day, calendar: calendar)
            if start > now {
                return ScheduledNeed(need: .boxingWarmup, from: start, until: end, line: boxingReason)
            }
        }
        return nil
    }

    /// True when the app should send today's invite for `reading` at `now`.
    /// - Parameters:
    ///   - lastInviteAt: when the last invite went out, `nil` if never.
    ///   - bedtime: no invite while it is `.on`.
    public static func shouldInvite(
        _ reading: NeedReading?,
        now: Date,
        lastInviteAt: Date?,
        bedtime: Bedtime,
        rules: NeedRules = .standard,
        calendar: Calendar = .current
    ) -> Bool {
        guard let reading, bedtime == .off else { return false }
        guard now.timeIntervalSince(reading.since) >= inviteWait(reading.need, rules: rules) else { return false }
        guard let last = lastInviteAt else { return true }
        let today = StateEngine.dayStart(for: now, calendar: calendar)
        return last < today && now.timeIntervalSince(last) >= rules.inviteCooldown
    }

    /// When boxing class starts, for the countdown: on boxing day while warm-up lasts and before class,
    /// else `nil`.
    public static func boxingCountdown(
        to reading: NeedReading?,
        now: Date,
        rules: NeedRules = .standard,
        calendar: Calendar = .current
    ) -> Date? {
        guard reading?.need == .boxingWarmup else { return nil }
        let start = time(rules.boxingStartMinute, on: now, calendar: calendar)
        return now < start ? start : nil
    }

    /// When the invite for `reading` should go out, at `now` or later, or `nil` when it shouldn't:
    /// the need ends first, today's invite went out, or it would land at bedtime.
    /// - Parameters:
    ///   - lastInviteAt: when the last invite went out, `nil` if never.
    ///   - bedtime: the bedtime window, checked at the time the invite would go out.
    public static func inviteTime(
        for reading: NeedReading?,
        now: Date,
        lastInviteAt: Date?,
        bedtime: BedtimeSchedule,
        rules: NeedRules = .standard,
        calendar: Calendar = .current
    ) -> Date? {
        guard let reading else { return nil }
        let at = max(reading.since.addingTimeInterval(inviteWait(reading.need, rules: rules)), now)
        guard reading.isActive(at: at) else { return nil }
        let state = bedtime.state(at: at, calendar: calendar)
        let invite = shouldInvite(
            reading,
            now: at,
            lastInviteAt: lastInviteAt,
            bedtime: state,
            rules: rules,
            calendar: calendar
        )
        return invite ? at : nil
    }

    /// The invite's text for `need`. It goes on the Lock Screen, so it doesn't say what Mike was doing.
    public static func inviteText(for need: CompanionNeed) -> String {
        switch need {
        case .couchScroll: "去健身房，或者下楼走走？"
        case .boxingWarmup: "拳套戴好了，出发去拳馆？"
        case .gymDay: "包背好了，走？"
        case .slacking: "嘘，我帮你望风。"
        }
    }

    /// The newest workout worth celebrating that hasn't been, or `nil`.
    /// - Parameter celebrated: ids of workouts already celebrated.
    public static func celebration(
        _ workouts: [WorkoutSummary],
        celebrated: Set<String>,
        now: Date,
        rules: NeedRules = .standard
    ) -> WorkoutSummary? {
        let fresh = workouts.filter { workout in
            let age = now.timeIntervalSince(workout.end)
            return !celebrated.contains(workout.id) && age >= 0 && age <= rules.celebrateWithin
        }
        return fresh.filter { isWorthCelebrating($0, rules: rules) }.max { $0.end < $1.end }
    }

    /// The line that says why RUNNER looks the way it does: bedtime, then the need, then energy.
    public static func whyLine(need: NeedReading?, energy: EnergyReading?, bedtime: Bedtime) -> String? {
        if bedtime == .on { return "到点了，我先困了" }
        if let reason = need?.reasons.first { return reason }
        return energy?.reasons.first
    }

    private static func inviteWait(_ need: CompanionNeed, rules: NeedRules) -> TimeInterval {
        switch need {
        case .couchScroll: rules.couchInviteAfter
        case .boxingWarmup: rules.boxingInviteAfter
        case .gymDay: rules.gymInviteAfter
        // Screen Time reports only after 30 minutes of use, so the notice goes out at once.
        case .slacking: 0
        }
    }

    static func isWorthCelebrating(_ workout: WorkoutSummary, rules: NeedRules) -> Bool {
        switch workout.kind {
        case .running: (workout.meters ?? 0) >= rules.celebrateRunMeters
        case .boxing: workout.duration >= rules.celebrateBoxing
        case .strength: workout.duration >= rules.celebrateStrength
        case .other: false
        }
    }

    private static func couchScroll(
        _ signals: NeedSignals,
        now: Date,
        rules: NeedRules,
        calendar: Calendar
    ) -> NeedReading? {
        // Away from a known home it isn't couch scrolling, whatever Screen Time says.
        let mayBeHome = signals.atHomeSince != nil || !signals.homeKnown
        if mayBeHome, let reading = screenTimeCouch(signals, now: now, rules: rules) {
            return reading
        }
        // Fallback when Screen Time isn't available: home in the evening and still for a while.
        guard let home = signals.atHomeSince, let still = signals.stillSince else { return nil }
        // Stillness only counts from arriving home and from the last manual mode change.
        let start = [still, home, signals.manualSince].compactMap { $0 }.max() ?? home
        let evening = time(rules.eveningStartMinute, on: now, calendar: calendar)
        let since = max(start.addingTimeInterval(rules.stillFor), evening)
        guard since <= now else { return nil }
        let reason = "在家 \(Int(now.timeIntervalSince(start) / 60)) 分钟没怎么动了，我也瘫着"
        return NeedReading(need: .couchScroll, since: since, reasons: [reason])
    }

    private static func boxingWarmup(
        _ signals: NeedSignals,
        now: Date,
        rules: NeedRules,
        calendar: Calendar
    ) -> NeedReading? {
        guard calendar.component(.weekday, from: now) == rules.boxingWeekday, !signals.atGym else { return nil }
        let start = time(rules.boxingWarmupStartMinute, on: now, calendar: calendar)
        let end = time(rules.boxingWarmupEndMinute, on: now, calendar: calendar)
        guard now >= start, now < end else { return nil }
        let midnight = calendar.startOfDay(for: now)
        let boxedToday = signals.workouts.contains { $0.kind == .boxing && $0.end >= midnight }
        guard !boxedToday else { return nil }
        return NeedReading(need: .boxingWarmup, since: start, reasons: [boxingReason], until: end)
    }

    private static let boxingReason = "今天打拳，拳套我戴好了"

    // Needs a known home: the invite is for still being at home, so an unknown place says nothing.
    private static func gymDay(
        _ signals: NeedSignals,
        now: Date,
        rules: NeedRules,
        days: ActivityDays,
        calendar: Calendar
    ) -> NeedReading? {
        guard days.gymWeekdays.contains(calendar.component(.weekday, from: now)) else { return nil }
        guard signals.atHomeSince != nil, !signals.departing else { return nil }
        let start = time(rules.gymInviteStartMinute, on: now, calendar: calendar)
        let end = time(rules.gymInviteEndMinute, on: now, calendar: calendar)
        guard now >= start, now < end else { return nil }
        let midnight = calendar.startOfDay(for: now)
        if let seen = signals.fitnessSeenAt, seen >= midnight { return nil }
        let trained = signals.workouts.contains { $0.kind != .running && $0.end >= midnight }
        guard !trained else { return nil }
        return NeedReading(need: .gymDay, since: start, reasons: ["健身日，包我背好了"], until: end)
    }

    private static func screenTimeCouch(_ signals: NeedSignals, now: Date, rules: NeedRules) -> NeedReading? {
        guard let reached = signals.scrollThresholdAt else { return nil }
        // The Lock Screen shows this, so it doesn't name the apps.
        let reading = NeedReading(need: .couchScroll, since: reached, reasons: ["手机刷够久了，我也瘫着"])
        return ongoing(reading, seen: signals.scrollSeenAt, signals: signals, now: now, rules: rules)
    }

    // Separate Screen Time reports, limited to work hours, so they never count toward the couch.
    private static func slacking(
        _ signals: NeedSignals,
        now: Date,
        rules: NeedRules,
        work: ModeRules,
        calendar: Calendar
    ) -> NeedReading? {
        guard let reached = signals.slackThresholdAt else { return nil }
        guard ModeEngine.scheduledMode(at: reached, rules: work, calendar: calendar) == .work else { return nil }
        let reading = NeedReading(need: .slacking, since: reached, reasons: ["上班时间，我帮你望风"])
        return ongoing(reading, seen: signals.slackSeenAt, signals: signals, now: now, rules: rules)
    }

    // Screen Time reports every few minutes of use, never when use stops. The need lasts while reports
    // keep coming, and ends early when Mike walks or changes mode by hand after the last one.
    private static func ongoing(
        _ reading: NeedReading,
        seen lastSeen: Date?,
        signals: NeedSignals,
        now: Date,
        rules: NeedRules
    ) -> NeedReading? {
        let reached = reading.since
        let seen = max(lastSeen ?? reached, reached)
        guard reached <= now, seen <= now, now.timeIntervalSince(seen) < rules.scrollQuiet else { return nil }
        if let still = signals.stillSince, still > seen { return nil }
        var result = reading
        if let manual = signals.manualSince, manual > reached {
            guard manual < seen else { return nil }
            result.since = seen
        }
        result.until = seen.addingTimeInterval(rules.scrollQuiet)
        return result
    }

    private static func time(_ minute: Int, on date: Date, calendar: Calendar) -> Date {
        let midnight = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .minute, value: minute, to: midnight) ?? midnight
    }
}
