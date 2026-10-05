import Foundation

// The app computes it; readers never touch the full log.
/// What widgets and the menu bar read.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var mode: Mode?
    public var since: Date?
    /// The 副业 state, `nil` in other modes or in snapshots from older builds.
    public var sideHustle: SideHustle?
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
    /// Start of the hub day of the last workout other than a run, so widgets know if today's gym is done.
    public var trainedDay: Date?
    /// Start of the hub day of the last run.
    public var ranDay: Date?
    /// What today left in HAKU's world as of `updatedAt`, `nil` in snapshots from older builds.
    public var traces: Set<CompanionTrace>?
    /// Traces that never fade, `nil` in snapshots from older builds.
    public var lasting: Set<CompanionTrace>?
    /// Time in work mode since 05:00 as of `updatedAt`, `nil` in snapshots from older builds.
    public var workedToday: TimeInterval?
    /// When Mike last changed the mode by hand, `nil` when never or unknown.
    public var manualAt: Date?
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
        sideHustle = log.current?.sideHustle
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
        case .mode(let change) where change.mode != mode || change.sideHustle != sideHustle:
            copy.mode = change.mode
            copy.since = change.at
            copy.sideHustle = change.sideHustle
            if change.source.isManual { copy.manualAt = change.at }
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

    /// The traces at `date`: the lasting ones, plus today's unless the snapshot was written before today's 05:00.
    public func traces(at date: Date, calendar: Calendar = .current) -> Set<CompanionTrace> {
        let today = updatedAt >= StateEngine.dayStart(for: date, calendar: calendar) ? traces ?? [] : []
        return today.union(lasting ?? [])
    }

    /// The signals for the states at home at `date`.
    /// - Parameter since: when Mike got home, `nil` when he isn't home.
    /// - Returns: `nil` when Mike isn't home.
    public func home(since: Date?, at date: Date, calendar: Calendar = .current) -> HomeSignals? {
        guard let since else { return nil }
        let today = updatedAt >= StateEngine.dayStart(for: date, calendar: calendar)
        return HomeSignals(since: since, workedToday: today ? workedToday ?? 0 : 0, manualAt: manualAt)
    }

    /// When the needs in this snapshot start, end or change stage (HAKU peeking during couch scrolling).
    public var needTimes: [Date] {
        let peek = need == .couchScroll ? needSince?.addingTimeInterval(NeedEngine.couchPeekAfter) : nil
        return [needUntil, nextNeed?.from, nextNeed?.until, peek].compactMap { $0 }
    }

    // HAKU's idle bits change every 15 minutes, counted from the reference date. A widget only redraws at
    // an entry, so each boundary needs one. Keep `slot` equal to `IdleLife.slotLength` in CompanionKit.
    /// The 15-minute boundaries after `date` for the next `span`, for widget timelines.
    public static func slotDates(
        after date: Date,
        every slot: TimeInterval = 15 * 60,
        span: TimeInterval = 6 * 60 * 60
    ) -> [Date] {
        let first = (date.timeIntervalSinceReferenceDate / slot).rounded(.down) + 1
        let count = Int(span / slot)
        return (0..<count).map { Date(timeIntervalSinceReferenceDate: (first + Double($0)) * slot) }
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
