import Foundation

// Mike approved the bath preview 2026-10-05 15:35Z; rules from PM: from 45 minutes before bedtime, only at
// home in Chill, for 30 minutes or until Mike taps HAKU. No push, no cans.
/// When HAKU heads off to take a bath before bedtime.
public enum BathTime {
    /// How long before bedtime the bath starts.
    public static let lead: TimeInterval = 45 * 60
    /// How long it lasts unless Mike taps HAKU.
    public static let lasts: TimeInterval = 30 * 60

    /// The bath window around `date`: from `lead` before a bedtime start, for `lasts`.
    /// - Returns: the window that contains `date`, or `nil` outside one.
    public static func window(
        at date: Date,
        bedtime: BedtimeSchedule,
        calendar: Calendar = .current
    ) -> DateInterval? {
        windows(near: date, bedtime: bedtime, calendar: calendar).first { $0.contains(date) && $0.end != date }
    }

    /// Whether HAKU takes its bath at `date`.
    /// - Parameters:
    ///   - mode: the current mode; only Chill.
    ///   - atHome: whether Mike is at home.
    ///   - doneAt: when Mike last tapped the bath away; it stays away for the rest of that window.
    public static func isOn(
        at date: Date,
        bedtime: BedtimeSchedule,
        mode: Mode?,
        atHome: Bool,
        doneAt: Date?,
        calendar: Calendar = .current
    ) -> Bool {
        guard mode == .chill, atHome, let window = window(at: date, bedtime: bedtime, calendar: calendar) else {
            return false
        }
        return !(doneAt.map { window.contains($0) } ?? false)
    }

    /// When bath windows start or end in the day after `date`, for widget timelines.
    public static func times(after date: Date, bedtime: BedtimeSchedule, calendar: Calendar = .current) -> [Date] {
        windows(near: date, bedtime: bedtime, calendar: calendar)
            .flatMap { [$0.start, $0.end] }
            .filter { $0 > date && $0 <= date.addingTimeInterval(24 * 3600) }
    }

    // Bedtime can be after midnight, so look at the bedtimes of yesterday, today and tomorrow.
    private static func windows(near date: Date, bedtime: BedtimeSchedule, calendar: Calendar) -> [DateInterval] {
        let today = calendar.startOfDay(for: date)
        return [-1, 0, 1].compactMap { offset -> DateInterval? in
            let day = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            guard let start = calendar.date(byAdding: .minute, value: bedtime.startMinute, to: day) else { return nil }
            return DateInterval(start: start.addingTimeInterval(-lead), duration: lasts)
        }
    }

    static let doneKey = "bathDone"

    /// When Mike last tapped the bath away, from `defaults`.
    public static func doneAt(in defaults: UserDefaults) -> Date? {
        defaults.object(forKey: doneKey) as? Date
    }

    /// Records that Mike tapped the bath away at `date`.
    public static func markDone(at date: Date, in defaults: UserDefaults) {
        defaults.set(date, forKey: doneKey)
    }
}
