import Foundation

/// A stretch of time spent in one mode, clipped to the day being shown.
public struct ModeSegment: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var mode: Mode
    public var source: ModeChange.Source
    public var tag: String?
    public var start: Date
    public var end: Date
    /// True for the segment that is still running.
    public var isOngoing: Bool

    public var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// The append-only history of mode changes. This is the on-disk document.
public struct ModeLog: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var changes: [ModeChange]

    public init(changes: [ModeChange] = []) {
        self.schemaVersion = Self.currentSchemaVersion
        self.changes = changes
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, changes }

    /// Lossy decoding: one unreadable record (for example a mode this build doesn't know) is skipped
    /// instead of losing the whole history.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        let items = try values.decodeIfPresent([Lossy].self, forKey: .changes) ?? []
        changes = items.compactMap(\.value)
    }

    private struct Lossy: Decodable {
        let value: ModeChange?
        init(from decoder: Decoder) throws { value = try? ModeChange(from: decoder) }
    }

    /// Non-deleted changes, oldest first.
    public var active: [ModeChange] {
        changes.filter { $0.deletedAt == nil }.sorted { $0.at < $1.at }
    }

    public var current: ModeChange? { active.last }

    /// Segments overlapping the calendar day containing `day`, ending at `now` for the running one.
    public func segments(on day: Date, now: Date = .now, calendar: Calendar = .current) -> [ModeSegment] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        let windowEnd = min(dayEnd, now)
        guard windowEnd > dayStart else { return [] }

        let sorted = active
        var result: [ModeSegment] = []
        for (index, change) in sorted.enumerated() {
            let next = index + 1 < sorted.count ? sorted[index + 1].at : nil
            let rawEnd = next ?? now
            let start = max(change.at, dayStart)
            let end = min(rawEnd, windowEnd)
            guard end > start else { continue }
            result.append(ModeSegment(
                id: change.id,
                mode: change.mode,
                source: change.source,
                tag: change.tag,
                start: start,
                end: end,
                isOngoing: next == nil && end == now
            ))
        }
        return result
    }

    /// Total time per mode on that day.
    public func totals(on day: Date, now: Date = .now, calendar: Calendar = .current) -> [Mode: TimeInterval] {
        segments(on: day, now: now, calendar: calendar)
            .reduce(into: [:]) { $0[$1.mode, default: 0] += $1.duration }
    }
}
