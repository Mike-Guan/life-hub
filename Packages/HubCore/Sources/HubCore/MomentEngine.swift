import Foundation

/// Picks the state within the mode HAKU acts out (PRD section 16). Same input, same output.
public enum MomentEngine {
    /// The state HAKU acts out at `now`: the 副业 state, then the gym-day states, then scrolling at work,
    /// then drowsy or overtime at the office.
    /// - Parameters:
    ///   - activity: what HAKU does alongside Mike; only the gym bag gives way to a gym-day state.
    ///   - need: the current need.
    ///   - departing: whether Mike said he is going to the gym.
    ///   - officeSince: when Mike arrived at the office, `nil` when he isn't there.
    /// - Returns: `nil` when HAKU shows the plain mode, activity or need.
    public static func moment(
        mode: Mode?,
        sideHustle: SideHustle?,
        activity: CompanionActivity?,
        need: CompanionNeed?,
        departing: Bool,
        officeSince: Date?,
        now: Date,
        rules: NeedRules = .standard,
        calendar: Calendar = .current
    ) -> CompanionMoment? {
        if let sideHustle { return sideHustle.moment }
        if let gym = GymDeparture.moment(activity: activity, need: need, departing: departing) { return gym }
        if need == .slacking { return .slacking }
        return office(mode: mode, since: officeSince, now: now, rules: rules, calendar: calendar)
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
