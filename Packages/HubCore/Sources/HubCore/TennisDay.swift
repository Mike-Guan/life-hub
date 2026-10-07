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
        let today = StateEngine.dayStart(for: now, calendar: calendar)
        var weeks: [Int: Set<Int>] = [:]
        for entry in ledger.active where entry.kind == .earned && entry.win == win && entry.at <= now {
            let day = StateEngine.dayStart(for: entry.at, calendar: calendar)
            let age = calendar.dateComponents([.day], from: day, to: today).day ?? .max
            guard (0..<ActivityDays.learnWeeks * 7).contains(age) else { continue }
            weeks[calendar.component(.weekday, from: day), default: []].insert(age / 7)
        }
        return weeks.filter { $0.value.count >= ActivityDays.learnMinWeeks }
            .min { ($1.value.count, $0.key) < ($0.value.count, $1.key) }?.key
    }
}
