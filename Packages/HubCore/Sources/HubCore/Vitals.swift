import Foundation

/// A coarse level of one of HAKU's hidden params. Low is the floor: tired, never sick.
public enum VitalBand: String, Codable, CaseIterable, Comparable, Sendable {
    case low
    case mid
    case high

    public static func < (lhs: VitalBand, rhs: VitalBand) -> Bool {
        (allCases.firstIndex(of: lhs) ?? 0) < (allCases.firstIndex(of: rhs) ?? 0)
    }
}

// PRD section 19 (Mike, 2026-10-05). The params only change how HAKU moves and talks. They never earn
// cans or unlock anything, and the UI never shows a number or a bar. Today's face still comes from
// last night's sleep alone.
/// HAKU's hidden params, as bands for CompanionKit to map to expression.
public struct HakuVitals: Codable, Equatable, Sendable {
    /// 体能: training over the last four weeks.
    public var stamina: VitalBand
    /// 元气: sleep over the last three nights, and daylight.
    public var spirit: VitalBand

    public init(stamina: VitalBand = .mid, spirit: VitalBand = .mid) {
        self.stamina = stamina
        self.spirit = spirit
    }
}

/// Works out HAKU's hidden params. Rules only: they rise fast and fall slowly.
public enum VitalsEngine {
    /// Wins that count as training.
    static let trainingWins: Set<Win> = [.boxing, .gym, .run5k]

    /// The params at `now` from the can ledger and the energy log.
    public static func vitals(
        ledger: CanLedger,
        energy: EnergyLog,
        now: Date,
        calendar: Calendar = .current
    ) -> HakuVitals {
        HakuVitals(
            stamina: stamina(ledger: ledger, now: now, calendar: calendar),
            spirit: spirit(energy: energy, ledger: ledger, now: now, calendar: calendar)
        )
    }

    // A training day this week counts 1, one from the three weeks before counts 0.5: a good week lifts it
    // at once, and it takes weeks of nothing to fall back.
    /// 体能 from the training days in the last 28 days.
    public static func stamina(ledger: CanLedger, now: Date, calendar: Calendar = .current) -> VitalBand {
        let today = StateEngine.dayStart(for: now, calendar: calendar)
        let days = Set(
            ledger.active
                .filter { $0.kind == .earned && $0.win.map(trainingWins.contains) == true && $0.at <= now }
                .map { StateEngine.dayStart(for: $0.at, calendar: calendar) }
        )
        let score = days.reduce(0.0) { total, day in
            let age = calendar.dateComponents([.day], from: day, to: today).day ?? 0
            switch age {
            case 0..<7: return total + 1
            case 7..<28: return total + 0.5
            default: return total
            }
        }
        if score >= 3 { return .high }
        return score >= 1.5 ? .mid : .low
    }

    // The better of last night and the three-night average: one good night lifts it, one bad night
    // after good ones doesn't drop it. Daylight today lifts it one step. No sleep data: mid.
    /// 元气 from the last three nights' sleep and daylight.
    public static func spirit(
        energy: EnergyLog,
        ledger: CanLedger,
        now: Date,
        thresholds: SleepThresholds = .standard,
        calendar: Calendar = .current
    ) -> VitalBand {
        let today = StateEngine.dayStart(for: now, calendar: calendar)
        guard let start = calendar.date(byAdding: .day, value: -2, to: today) else { return .mid }
        let nights = energy.active
            .filter { $0.kind == .sleep && $0.at >= start && $0.at <= now }
            .compactMap(\.sleepMinutes)
        guard let last = nights.last else { return .mid }
        let average = nights.reduce(0, +) / nights.count
        let slept = max(level(forSleep: last, thresholds), level(forSleep: average, thresholds))
        let sunny = ledger.active.contains { $0.kind == .earned && $0.win == .daylight && $0.at >= today }
        guard sunny, slept != .high else { return slept }
        return slept == .low ? .mid : .high
    }

    private static func level(forSleep minutes: Int, _ thresholds: SleepThresholds) -> VitalBand {
        switch thresholds.level(forSleep: minutes) {
        case .low: .low
        case .okay: .mid
        case .full: .high
        }
    }
}
