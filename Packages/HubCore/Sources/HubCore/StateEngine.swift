import Foundation

/// Today's energy and why.
public struct EnergyReading: Equatable, Sendable {
    public var level: EnergyLevel
    /// Plain sentences, shown to Mike as the reason.
    public var reasons: [String]
    /// The event this reading came from.
    public var source: EnergyEvent.Kind

    /// The 0-100 value for the companion.
    public var value: Double { level.value }
}

/// Sleep thresholds, in minutes asleep.
public struct SleepThresholds: Equatable, Sendable {
    /// Below this is low.
    public var lowBelow: Int
    /// At or above this is full.
    public var fullFrom: Int

    /// Under 6 h low, 6 to 7.5 h okay, 7.5 h and more full.
    public static let standard = SleepThresholds(lowBelow: 6 * 60, fullFrom: 7 * 60 + 30)

    public init(lowBelow: Int, fullFrom: Int) {
        self.lowBelow = lowBelow
        self.fullFrom = fullFrom
    }

    /// The level for `minutes` asleep.
    public func level(forSleep minutes: Int) -> EnergyLevel {
        if minutes < lowBelow { return .low }
        if minutes >= fullFrom { return .full }
        return .okay
    }
}

/// Rule-based state. Same input, same output; every result says why.
public enum StateEngine {
    // 05:00 is when the bedtime window ends, so a late-night self-report still counts for the
    // evening before.
    /// Hour at which the hub's day starts.
    public static let dayStartHour = 5

    /// Start of the hub day containing `date`.
    public static func dayStart(for date: Date, calendar: Calendar = .current) -> Date {
        let midnight = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .hour, value: dayStartHour, to: midnight) ?? midnight
        if date >= start { return start }
        return calendar.date(byAdding: .day, value: -1, to: start) ?? start
    }

    // Mike (PRD section 16, 2026-10-06): after a short night, scrolling on the couch is rest, so no walk invite.
    /// Whether the sleep that ended today was shorter than `thresholds.lowBelow`. A self-report doesn't count.
    public static func sleptShort(
        events: [EnergyEvent],
        now: Date,
        calendar: Calendar = .current,
        thresholds: SleepThresholds = .standard
    ) -> Bool {
        let start = dayStart(for: now, calendar: calendar)
        let nights = events.filter { $0.deletedAt == nil && $0.kind == .sleep && $0.at >= start && $0.at <= now }
        let night = nights.max { $0.at < $1.at }
        return night?.sleepMinutes.map { $0 < thresholds.lowBelow } ?? false
    }

    /// Today's energy from `events`: Mike's latest self-report today wins, otherwise the sleep
    /// that ended today. `nil` when there is neither; the UI then shows energy as unknown.
    public static func energy(
        events: [EnergyEvent],
        now: Date,
        calendar: Calendar = .current,
        thresholds: SleepThresholds = .standard
    ) -> EnergyReading? {
        let start = dayStart(for: now, calendar: calendar)
        let inWindow = events.filter { $0.deletedAt == nil && $0.at >= start && $0.at <= now }
        let today = inWindow.sorted { $0.at < $1.at }

        if let level = today.last(where: { $0.kind == .selfReport && $0.level != nil })?.level {
            return EnergyReading(level: level, reasons: ["你自己选了「\(level.title)」"], source: .selfReport)
        }
        if let minutes = today.last(where: { $0.kind == .sleep && $0.sleepMinutes != nil })?.sleepMinutes {
            let level = thresholds.level(forSleep: minutes)
            let reason = "昨晚睡了 \(minutes / 60) 小时 \(minutes % 60) 分，算「\(level.title)」"
            return EnergyReading(level: level, reasons: [reason], source: .sleep)
        }
        return nil
    }
}
