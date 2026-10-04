import Foundation

// The app computes it; readers never touch the full log.
/// What widgets and the menu bar read.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var mode: Mode?
    public var since: Date?
    /// Today's energy, `nil` when unknown.
    public var energy: EnergyLevel?
    /// Bedtime state when the snapshot was taken, `nil` in snapshots from older builds.
    public var bedtime: Bedtime?
    /// What RUNNER acts out, `nil` when there is no need or in snapshots from older builds.
    public var need: CompanionNeed?
    /// When `need` started, `nil` when unknown.
    public var needSince: Date?
    /// When `need` ends at the latest, `nil` when no time is known.
    public var needUntil: Date?
    /// Why RUNNER looks the way it does, for the rectangular Lock Screen widget.
    public var line: String?
    /// The line to show once `need` has ended.
    public var lineAfterNeed: String?
    /// The next need that depends only on the clock, shown even if the app hasn't run since.
    public var nextNeed: ScheduledNeed?
    /// Workouts from the app's last HealthKit reading, so widgets know if today's gym or run is done.
    public var workouts: [WorkoutSummary]?
    public var updatedAt: Date

    public init(
        mode: Mode?,
        since: Date?,
        energy: EnergyLevel? = nil,
        bedtime: Bedtime? = nil,
        need: CompanionNeed? = nil,
        line: String? = nil,
        updatedAt: Date
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.mode = mode
        self.since = since
        self.energy = energy
        self.bedtime = bedtime
        self.need = need
        self.line = line
        self.updatedAt = updatedAt
    }

    public init(log: ModeLog, energy: EnergyLevel? = nil, bedtime: Bedtime? = nil, now: Date = .now) {
        self.init(mode: log.current?.mode, since: log.current?.at, energy: energy, bedtime: bedtime, updatedAt: now)
    }
}

extension WidgetSnapshot {
    /// The snapshot stored at `url`, or `nil` when there is none or it can't be decoded.
    public static func read(from url: URL) -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? HubJSON.decoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Writes the snapshot to `url`.
    /// - Throws: file system or encoding errors.
    public func write(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try HubJSON.encoder().encode(self).write(to: url, options: .atomic)
    }

    /// This snapshot with `item` applied, for widgets to show a change before the app runs.
    public func applying(_ item: InboxItem) -> WidgetSnapshot {
        var copy = self
        switch item {
        case .mode(let change) where change.mode != mode:
            copy.mode = change.mode
            copy.since = change.at
        case .energy(let event) where event.kind == .selfReport:
            copy.energy = event.level
        default:
            break
        }
        copy.updatedAt = max(updatedAt, item.at)
        return copy
    }

    // Energy is per hub day. A snapshot from before today's 05:00 says nothing about today.
    /// Today's energy as of `date`.
    public func energy(at date: Date, calendar: Calendar = .current) -> EnergyLevel? {
        updatedAt >= StateEngine.dayStart(for: date, calendar: calendar) ? energy : nil
    }

    /// The need as of `date`: the scheduled one while it lasts, else `need` unless it was written
    /// before today's 05:00 or has ended.
    public func need(at date: Date, calendar: Calendar = .current) -> CompanionNeed? {
        if let nextNeed, nextNeed.contains(date) { return nextNeed.need }
        guard updatedAt >= StateEngine.dayStart(for: date, calendar: calendar) else { return nil }
        if let needUntil, date >= needUntil { return nil }
        return need
    }

    /// When the need shown at `date` started: the scheduled one's start while it lasts, else `needSince`
    /// while `need` is shown.
    public func needSince(at date: Date, calendar: Calendar = .current) -> Date? {
        if let nextNeed, nextNeed.contains(date) { return nextNeed.from }
        return need(at: date, calendar: calendar) == nil ? nil : needSince
    }

    /// The "why" line as of `date`: the scheduled need's while it lasts, else `nil` when it was
    /// written before today's 05:00.
    public func line(at date: Date, calendar: Calendar = .current) -> String? {
        if let nextNeed, nextNeed.contains(date) { return nextNeed.line }
        guard updatedAt >= StateEngine.dayStart(for: date, calendar: calendar) else { return nil }
        if need != nil, need(at: date, calendar: calendar) == nil { return lineAfterNeed }
        return line
    }

    /// When the needs in this snapshot start, end or change stage (HAKU peeking during couch scrolling).
    public var needTimes: [Date] {
        let peek = need == .couchScroll ? needSince?.addingTimeInterval(NeedEngine.couchPeekAfter) : nil
        return [needUntil, nextNeed?.from, nextNeed?.until, peek].compactMap { $0 }
    }

    /// When widgets should redraw after `date`: now, the next bedtime change, the next day start and
    /// when needs start or end.
    /// - Parameter needTimes: when the snapshot's needs start or end.
    public static func timelineDates(
        after date: Date,
        bedtime schedule: BedtimeSchedule,
        needTimes: [Date] = [],
        calendar: Calendar = .current
    ) -> [Date] {
        var dates = [date]
        dates += needTimes.filter { $0 > date }
        if let change = schedule.nextChange(after: date, calendar: calendar) {
            dates.append(change)
        }
        let today = StateEngine.dayStart(for: date, calendar: calendar)
        if let next = calendar.date(byAdding: .day, value: 1, to: today) {
            dates.append(next)
        }
        return Array(Set(dates)).sorted()
    }
}
