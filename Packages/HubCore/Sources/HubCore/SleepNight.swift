import Foundation

/// One stretch of time the health store marks as asleep.
public struct SleepInterval: Equatable, Sendable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

/// Last night's sleep, reduced to what the energy rules need.
public struct SleepNight: Equatable, Sendable {
    /// Same for every import of the same night, so re-imports update one event.
    public var id: UUID
    public var minutes: Int
    public var endedAt: Date

    /// How many hours before the hub day starts the night may begin.
    static let lookback: TimeInterval = 12 * 60 * 60

    /// The span to read sleep from for the hub day containing `now`: 17:00 the evening before until `now`.
    public static func window(for now: Date, calendar: Calendar = .current) -> DateInterval {
        let start = StateEngine.dayStart(for: now, calendar: calendar).addingTimeInterval(-lookback)
        return DateInterval(start: start, end: max(start, now))
    }

    /// Joins overlapping intervals (Watch and iPhone both record) into one night.
    /// - Returns: `nil` when no sleep ended in the current hub day.
    public static func from(_ intervals: [SleepInterval], now: Date, calendar: Calendar = .current) -> SleepNight? {
        let window = window(for: now, calendar: calendar)
        let clipped = intervals.compactMap { interval -> SleepInterval? in
            let start = max(interval.start, window.start)
            let end = min(interval.end, window.end)
            return end > start ? SleepInterval(start: start, end: end) : nil
        }
        var total: TimeInterval = 0
        var covered: Date?
        for interval in clipped.sorted(by: { $0.start < $1.start }) {
            let start = max(interval.start, covered ?? interval.start)
            if interval.end > start { total += interval.end.timeIntervalSince(start) }
            covered = max(covered ?? interval.end, interval.end)
        }
        let dayStart = StateEngine.dayStart(for: now, calendar: calendar)
        guard let endedAt = covered, endedAt >= dayStart, total > 0 else { return nil }
        return SleepNight(id: nightID(dayStart, calendar: calendar), minutes: Int(total / 60), endedAt: endedAt)
    }

    // A fixed prefix plus the date, so the id depends only on the night.
    static func nightID(_ dayStart: Date, calendar: Calendar) -> UUID {
        let parts = calendar.dateComponents([.year, .month, .day], from: dayStart)
        let date = String(format: "%04X-%02X%02X", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return UUID(uuidString: "4C48534C-4545-5000-\(date)00000000") ?? UUID()
    }
}
