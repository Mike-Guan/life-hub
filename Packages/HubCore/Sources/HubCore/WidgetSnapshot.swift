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
    /// Why RUNNER looks the way it does, for the rectangular Lock Screen widget.
    public var line: String?
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

    /// The "why" line as of `date`, `nil` when it was written before today's 05:00.
    public func line(at date: Date, calendar: Calendar = .current) -> String? {
        updatedAt >= StateEngine.dayStart(for: date, calendar: calendar) ? line : nil
    }

    /// When widgets should redraw after `date`: now, the next bedtime change and the next day start.
    public static func timelineDates(
        after date: Date,
        bedtime schedule: BedtimeSchedule,
        calendar: Calendar = .current
    ) -> [Date] {
        var dates = [date]
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
