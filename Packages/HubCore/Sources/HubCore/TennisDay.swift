import Foundation

// Issue #164 gave the second character a learned identity day. PM 2026-10-13 (写死作息排查 v0 #7): every
// character learns it from the identity wins, and there is none until one is learned.
extension NeedRules {
    /// The rules for `persona`, with the identity day learned from the identity wins in `ledger`. On that
    /// day the warm-up runs from an hour before the usual arrival to two hours after, and the countdown
    /// runs to the arrival.
    /// - Parameter arrivals: when the user switched to the identity card.
    public static func standard(
        for persona: Persona,
        ledger: CanLedger,
        arrivals: [Date] = [],
        now: Date,
        calendar: Calendar = .current
    ) -> NeedRules {
        var rules = NeedRules.standard
        rules.persona = persona
        guard let weekday = learnedWeekday(of: .boxing, in: ledger, now: now, calendar: calendar),
            let arrival = usualArrival(on: weekday, arrivals: arrivals, ledger: ledger, now: now, calendar: calendar)
        else { return rules }
        rules.boxingWeekday = weekday
        rules.boxingStartMinute = arrival
        rules.boxingWarmupStartMinute = arrival - 60
        rules.boxingWarmupEndMinute = arrival + 120
        rules.boxingFirstUntilMinute = arrival + 30
        return rules
    }

    // A win only stores when the session ended, so without arrivals a session and the way there count as
    // 90 minutes.
    /// The usual arrival on `weekday` in minutes after midnight, rounded down to 15 minutes and at least
    /// 01:00: the middle one of the recent `arrivals` on that weekday, else of the identity wins there
    /// minus 90 minutes. `nil` when there are neither.
    static func usualArrival(
        on weekday: Int,
        arrivals: [Date],
        ledger: CanLedger,
        now: Date,
        calendar: Calendar
    ) -> Int? {
        let today = StateEngine.dayStart(for: now, calendar: calendar)
        var minutes = arrivals.compactMap { at -> Int? in
            let day = StateEngine.dayStart(for: at, calendar: calendar)
            let age = calendar.dateComponents([.day], from: day, to: today).day ?? .max
            guard at <= now, (0..<ActivityDays.learnWeeks * 7).contains(age),
                calendar.component(.weekday, from: day) == weekday
            else { return nil }
            return ActivityDays.minutesAfterMidnight(at, on: day, calendar: calendar)
        }
        if minutes.isEmpty {
            minutes = ActivityDays.recentWins(.boxing, in: ledger, now: now, calendar: calendar)
                .filter { calendar.component(.weekday, from: $0.day) == weekday }
                .map { ActivityDays.minutesAfterMidnight($0.at, on: $0.day, calendar: calendar) - 90 }
        }
        let sorted = minutes.sorted()
        guard !sorted.isEmpty else { return nil }
        return max(60, sorted[sorted.count / 2] / 15 * 15)
    }

    /// The weekday with a `win` in the most of the last `ActivityDays.learnWeeks` weeks, if it reaches
    /// `ActivityDays.learnMinWeeks`; the earlier weekday wins a tie.
    static func learnedWeekday(of win: Win, in ledger: CanLedger, now: Date, calendar: Calendar) -> Int? {
        ActivityDays.mostWon(ActivityDays.weeksWon(win, in: ledger, now: now, calendar: calendar))
    }
}
