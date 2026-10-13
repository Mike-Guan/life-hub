import Foundation

// Issue #164. KURO's identity day is tennis, with boxing's rules. Her day follows the days she actually
// goes, like gym days; Saturday until one qualifies. HAKU keeps Mike's fixed boxing Sunday.
extension NeedRules {
    /// KURO's tennis day until one is learned: Saturday.
    public static let tennisWeekday = 7

    /// The rules for `persona`: HAKU's are `standard`; KURO's use her lines and her learned tennis day.
    public static func standard(
        for persona: Persona,
        ledger: CanLedger,
        now: Date,
        calendar: Calendar = .current
    ) -> NeedRules {
        guard persona == .kuro else { return .standard }
        var rules = NeedRules.standard
        rules.persona = .kuro
        rules.boxingWeekday = learnedWeekday(of: .boxing, in: ledger, now: now, calendar: calendar) ?? tennisWeekday
        return rules
    }

    /// The weekday with a `win` in the most of the last `ActivityDays.learnWeeks` weeks, if it reaches
    /// `ActivityDays.learnMinWeeks`; the earlier weekday wins a tie.
    static func learnedWeekday(of win: Win, in ledger: CanLedger, now: Date, calendar: Calendar) -> Int? {
        ActivityDays.mostWon(ActivityDays.weeksWon(win, in: ledger, now: now, calendar: calendar))
    }
}
