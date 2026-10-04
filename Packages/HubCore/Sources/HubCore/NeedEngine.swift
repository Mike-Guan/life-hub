import Foundation

/// What RUNNER acts out when Mike seems to need something. At most one at a time.
public enum CompanionNeed: String, Codable, CaseIterable, Sendable {
    /// Lying at home scrolling Bilibili or Xiaohongshu.
    case couchScroll
    /// Boxing day and not at the gym yet.
    case boxingWarmup
}

/// A short animation RUNNER plays once, then goes back to its usual look.
public enum CompanionEvent: Equatable, Sendable {
    /// Celebrate a workout of `kind`; `id` is the workout's id, so each one plays once.
    case celebrate(id: String, kind: WorkoutSummary.Kind)
    /// The off-work animation after the off-work notification is tapped; `id` is the day, "yyyy-MM-dd".
    case offWork(id: String)
}

/// A workout from the Health app, reduced to what the hub uses.
public struct WorkoutSummary: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case boxing
        case running
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
    /// How long couch scrolling lasts after the Screen Time threshold is reached.
    public var scrollLasts: TimeInterval
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

    // Defaults from Issue #23 (Mike's smaller first version, 2026-10-03). Starting guesses.
    /// Couch after 19:00 and 60 still minutes, or 3 h after the Screen Time threshold; boxing Sunday
    /// 9:00 to 12:00 with class at 10:00; invites after 60 / 30 min.
    public static let standard = NeedRules(
        eveningStartMinute: 19 * 60,
        stillFor: 60 * 60,
        scrollLasts: 3 * 60 * 60,
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
        scrollLasts: TimeInterval,
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
        celebrateBoxing: TimeInterval
    ) {
        self.eveningStartMinute = eveningStartMinute
        self.stillFor = stillFor
        self.scrollLasts = scrollLasts
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
    }
}

/// What the app knows right now that needs depend on. Unknown signals are `nil` or `false`.
public struct NeedSignals: Equatable, Sendable {
    /// When today's Screen Time threshold for Bilibili and Xiaohongshu was reached.
    public var scrollThresholdAt: Date?
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

    public init(
        scrollThresholdAt: Date? = nil,
        atHomeSince: Date? = nil,
        homeKnown: Bool = false,
        stillSince: Date? = nil,
        atGym: Bool = false,
        workouts: [WorkoutSummary] = []
    ) {
        self.scrollThresholdAt = scrollThresholdAt
        self.atHomeSince = atHomeSince
        self.homeKnown = homeKnown
        self.stillSince = stillSince
        self.atGym = atGym
        self.workouts = workouts
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

    /// The need at `now`, or `nil` when there is none. Couch scrolling comes first, except on a
    /// boxing morning, when scrolling at home is exactly what boxing warm-up is about.
    public static func need(
        _ signals: NeedSignals,
        now: Date,
        rules: NeedRules = .standard,
        calendar: Calendar = .current
    ) -> NeedReading? {
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
        case .couchScroll: "起来走两步？我陪你。"
        case .boxingWarmup: "拳套戴好了，出发去拳馆？"
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
        need == .couchScroll ? rules.couchInviteAfter : rules.boxingInviteAfter
    }

    private static func isWorthCelebrating(_ workout: WorkoutSummary, rules: NeedRules) -> Bool {
        switch workout.kind {
        case .running: (workout.meters ?? 0) >= rules.celebrateRunMeters
        case .boxing: workout.duration >= rules.celebrateBoxing
        case .other: false
        }
    }

    private static func couchScroll(
        _ signals: NeedSignals,
        now: Date,
        rules: NeedRules,
        calendar: Calendar
    ) -> NeedReading? {
        let today = StateEngine.dayStart(for: now, calendar: calendar)
        // Away from a known home it isn't couch scrolling, whatever Screen Time says.
        let mayBeHome = signals.atHomeSince != nil || !signals.homeKnown
        if let reached = signals.scrollThresholdAt, mayBeHome, isFresh(reached, today: today, now: now, rules: rules) {
            // The Lock Screen shows this, so it doesn't name the apps.
            let until = reached.addingTimeInterval(rules.scrollLasts)
            return NeedReading(need: .couchScroll, since: reached, reasons: ["手机刷够久了，我也瘫着"], until: until)
        }
        // Fallback when Screen Time isn't available: home in the evening and still for a while.
        guard let home = signals.atHomeSince, let still = signals.stillSince else { return nil }
        // Stillness only counts from arriving home.
        let start = max(still, home)
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

    private static func isFresh(_ reached: Date, today: Date, now: Date, rules: NeedRules) -> Bool {
        reached >= today && reached <= now && now.timeIntervalSince(reached) < rules.scrollLasts
    }

    private static func time(_ minute: Int, on date: Date, calendar: Calendar) -> Date {
        let midnight = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .minute, value: minute, to: midnight) ?? midnight
    }
}
