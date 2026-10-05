import Foundation

// Daily Widget's own format (PlannerTask schema v2), read from the folder it syncs through iCloud
// Drive. Life Hub never writes it. iOS leaves out nil keys and writes dates without fractional
// seconds; the Mac app writes null keys and milliseconds.
/// A task from Daily Widget, read only.
public struct DailyTask: Decodable, Equatable, Sendable {
    /// How a task repeats.
    public enum Recurrence: String, Sendable {
        case none
        case daily
        /// Monday to Friday.
        case weekdays
        /// The weekday of `date`, every week.
        case weekly
    }

    public var id: String
    public var title: String
    /// The day it happens, or the first day for a repeating task, as "yyyy-MM-dd". `nil` when not scheduled.
    public var date: String?
    /// Minutes after midnight of the day.
    public var start: Int?
    /// Minutes after midnight of the day; above 1440 ends on the next day.
    public var end: Int?
    public var recurrence: Recurrence
    /// Whether a one-off task is done.
    public var done: Bool
    /// Days a repeating task was done, as "yyyy-MM-dd".
    public var completedDates: [String]
    /// Whether a one-off task is the day's focus.
    public var focus: Bool
    /// Days a repeating task is the day's focus, as "yyyy-MM-dd".
    public var focusDates: [String]
    public var createdAt: Date?
    public var deletedAt: Date?

    public init(
        id: String,
        title: String = "",
        date: String?,
        start: Int?,
        end: Int?,
        recurrence: Recurrence = .none,
        done: Bool = false,
        completedDates: [String] = [],
        focus: Bool = false,
        focusDates: [String] = [],
        createdAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.start = start
        self.end = end
        self.recurrence = recurrence
        self.done = done
        self.completedDates = completedDates
        self.focus = focus
        self.focusDates = focusDates
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, date, start, end, recurrence, done, completedDates, focus, focusDates, createdAt, deletedAt
    }

    // Every field but the id falls back to a default, so a file from a newer Daily still reads.
    /// Decodes a task. Only `id` is required.
    /// - Throws: `DecodingError` when `id` is missing.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        func value<T: Decodable>(_ key: CodingKeys) -> T? {
            (try? values.decodeIfPresent(T.self, forKey: key)) ?? nil
        }
        title = value(.title) ?? ""
        date = value(.date)
        start = value(.start)
        end = value(.end)
        recurrence = (value(.recurrence) as String?).flatMap(Recurrence.init(rawValue:)) ?? .none
        done = value(.done) ?? false
        completedDates = value(.completedDates) ?? []
        focus = value(.focus) ?? false
        focusDates = value(.focusDates) ?? []
        createdAt = (value(.createdAt) as String?).flatMap(Self.date(from:))
        deletedAt = (value(.deletedAt) as String?).flatMap(Self.date(from:))
    }

    /// Parses an ISO 8601 date with or without fractional seconds.
    static func date(from text: String) -> Date? {
        let plain = Date.ISO8601FormatStyle()
        let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        return (try? plain.parse(text)) ?? (try? fractional.parse(text))
    }
}

/// One time a Daily task happens.
public struct DailyOccurrence: Equatable, Sendable {
    /// The task id, plus the day for a repeating task.
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var done: Bool
    public var focus: Bool
    /// Whether the task was created before it starts, not added on the spot.
    public var planned: Bool

    public init(id: String, title: String, start: Date, end: Date, done: Bool, focus: Bool, planned: Bool) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.done = done
        self.focus = focus
        self.planned = planned
    }
}

extension DailyTask {
    /// The time this task happens on the calendar day of `day`.
    /// - Returns: `nil` when it is deleted, has no time or doesn't happen that day.
    public func occurrence(on day: Date, calendar: Calendar = .current) -> DailyOccurrence? {
        guard deletedAt == nil, let date, let start, let end else { return nil }
        let midnight = calendar.startOfDay(for: day)
        let key = DailyAgenda.key(for: midnight, calendar: calendar)
        guard happens(on: midnight, key: key, first: date, calendar: calendar) else { return nil }
        let at = { (minute: Int) in calendar.date(byAdding: .minute, value: minute, to: midnight) ?? midnight }
        let repeating = recurrence != .none
        return DailyOccurrence(
            id: repeating ? "\(id):\(key)" : id,
            title: title,
            start: at(start),
            end: at(max(end, start)),
            done: repeating ? completedDates.contains(key) : done,
            focus: repeating ? focusDates.contains(key) : focus,
            planned: createdAt.map { $0 < at(start) } ?? false
        )
    }

    // "yyyy-MM-dd" strings sort like the days they name.
    private func happens(on midnight: Date, key: String, first: String, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: midnight)
        switch recurrence {
        case .none:
            return key == first
        case .daily:
            return key >= first
        case .weekdays:
            return key >= first && (2...6).contains(weekday)
        case .weekly:
            guard key >= first, let firstDay = DailyAgenda.day(from: first, calendar: calendar) else { return false }
            return calendar.component(.weekday, from: firstDay) == weekday
        }
    }
}

// PRD section 15. Rules only (T0).
/// What Life Hub takes from Daily Widget: the timed tasks around today and the cans for planned ones.
public enum DailyAgenda {
    /// Planned tasks that earn a can on one hub day at most.
    public static let dailyCanLimit = 3

    /// The timed tasks from yesterday to tomorrow, by start time. Yesterday is there so a task done late
    /// last night still earns its can when the app opens today.
    public static func occurrences(
        _ tasks: [DailyTask],
        now: Date,
        calendar: Calendar = .current
    ) -> [DailyOccurrence] {
        let today = calendar.startOfDay(for: now)
        let days = [-1, 0, 1].compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let all = days.flatMap { day in tasks.compactMap { $0.occurrence(on: day, calendar: calendar) } }
        return all.sorted { ($0.start, $0.id) < ($1.start, $1.id) }
    }

    /// The next task not done yet that starts at or after `now`, today or tomorrow.
    public static func next(in occurrences: [DailyOccurrence], after now: Date) -> DailyOccurrence? {
        occurrences.first { !$0.done && $0.start >= now }
    }

    // Daily keeps no time of finishing, so a finish counts on the hub day Life Hub first reads it.
    // Un-finishing never takes the can back: the ledger only grows.
    /// The planned tasks done that still earn a can at `now`, up to the limit for today's hub day.
    public static func wins(
        in occurrences: [DailyOccurrence],
        ledger: CanLedger,
        now: Date,
        calendar: Calendar = .current
    ) -> [EarnedWin] {
        let dayStart = StateEngine.dayStart(for: now, calendar: calendar)
        let earned = ledger.entries.filter { $0.kind == .earned && $0.win == .plannedTask }
        let today = earned.filter { $0.at >= dayStart && $0.deletedAt == nil }.count
        let room = max(dailyCanLimit - today, 0)
        let known = Set(earned.map(\.id))
        let fresh = occurrences.filter { $0.planned && $0.done }.map {
            EarnedWin(win: .plannedTask, source: $0.id, at: now)
        }
        let unrecorded = fresh.filter { win in
            !known.contains(CanEntry.earned(win.win, source: win.source, at: now, deviceID: "").id)
        }
        return Array(unrecorded.prefix(room))
    }

    /// The "yyyy-MM-dd" key Daily uses for the calendar day of `date`.
    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The start of the day a "yyyy-MM-dd" key names, `nil` when it isn't one.
    static func day(from key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
