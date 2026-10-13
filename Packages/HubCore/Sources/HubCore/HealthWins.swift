import Foundation

// Issue #279: the daylight and on-time sleep wins of 03 Product/奖励数值表.md §2. Thresholds from PM
// (03 Product/商店与奖励打磨清单 v0.md §6). Each entry is dated at the hub day or the set bedtime, never at
// a time read from HealthKit, so the ledger holds no sleep or daylight times.
extension Win {
    /// Daylight a hub day needs to earn the daylight win.
    public static let daylightMinimum: TimeInterval = 15 * 60
    /// How long after the set bedtime falling asleep still counts as on time.
    public static let earlySleepGrace: TimeInterval = 30 * 60
    /// Asleep stretches closer than this belong to one sleep.
    static let sleepGap: TimeInterval = 60 * 60

    /// The daylight win for the hub day containing `now`, after `daylight` seconds in daylight that day.
    /// - Returns: `nil` below `daylightMinimum`.
    public static func daylight(_ daylight: TimeInterval, now: Date, calendar: Calendar = .current) -> EarnedWin? {
        guard daylight >= daylightMinimum else { return nil }
        let day = StateEngine.dayStart(for: now, calendar: calendar)
        return EarnedWin(win: .daylight, source: Win.daylight.source(at: day, calendar: calendar), at: now)
    }

    /// The on-time sleep win for last night: its longest sleep began no later than `earlySleepGrace` after
    /// the bedtime in `schedule`.
    /// - Parameters:
    ///   - intervals: the asleep intervals read for `SleepNight.window(for: now)`.
    ///   - schedule: the bedtime the user set.
    ///   - now: a moment in the hub day the night ended in.
    ///   - calendar: the calendar for hub days.
    /// - Returns: `nil` when there was no sleep ending this hub day or it began too late.
    public static func earlySleep(
        _ intervals: [SleepInterval],
        schedule: BedtimeSchedule,
        now: Date,
        calendar: Calendar = .current
    ) -> EarnedWin? {
        guard SleepNight.from(intervals, now: now, calendar: calendar) != nil else { return nil }
        let window = SleepNight.window(for: now, calendar: calendar)
        let clipped = intervals.compactMap { interval -> SleepInterval? in
            let start = max(interval.start, window.start)
            let end = min(interval.end, window.end)
            return end > start ? SleepInterval(start: start, end: end) : nil
        }
        var blocks: [SleepInterval] = []
        for interval in clipped.sorted(by: { $0.start < $1.start }) {
            if let last = blocks.last, interval.start.timeIntervalSince(last.end) < sleepGap {
                blocks[blocks.count - 1].end = max(last.end, interval.end)
            } else {
                blocks.append(interval)
            }
        }
        let longest = blocks.max { $0.end.timeIntervalSince($0.start) < $1.end.timeIntervalSince($1.start) }
        let dayStart = StateEngine.dayStart(for: now, calendar: calendar)
        guard let longest, let bedtime = bedtime(before: dayStart, schedule: schedule, calendar: calendar),
            longest.start <= bedtime.addingTimeInterval(earlySleepGrace)
        else { return nil }
        return EarnedWin(win: .earlySleep, source: Win.earlySleep.source(at: dayStart, calendar: calendar), at: bedtime)
    }

    /// The last bedtime in `schedule` before the hub day starting at `dayStart`.
    static func bedtime(before dayStart: Date, schedule: BedtimeSchedule, calendar: Calendar) -> Date? {
        let hour = schedule.startMinute / 60
        let minute = schedule.startMinute % 60
        guard let sameDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) else {
            return nil
        }
        return sameDate <= dayStart ? sameDate : calendar.date(byAdding: .day, value: -1, to: sameDate)
    }
}
