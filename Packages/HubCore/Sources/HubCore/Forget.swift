import Foundation

// Issue #237: the user can delete what the companion remembers. A delete only sets `deletedAt`, so a
// build that still has the record never brings it back (DW-02), and every engine already skips it.
/// A record that is deleted by marking it, never by removing it.
public protocol SoftDeletable: Identifiable where ID == UUID {
    /// When the record happened.
    var at: Date { get }
    var deletedAt: Date? { get set }
    var updatedAt: Date { get set }
    var updatedBy: String { get set }
}

extension ModeChange: SoftDeletable {}
extension EnergyEvent: SoftDeletable {}
extension Decision: SoftDeletable {}

/// How much one store remembers: the number of records and the time they span.
public struct MemorySummary: Equatable, Sendable {
    public var count: Int
    public var first: Date?
    public var last: Date?
}

extension RecordLog where Record: SoftDeletable {
    /// The records not deleted, oldest first.
    public var kept: [Record] {
        records.filter { $0.deletedAt == nil }.sorted { $0.at < $1.at }
    }

    /// The count and time span of the records not deleted.
    public var summary: MemorySummary {
        let list = kept
        return MemorySummary(count: list.count, first: list.first?.at, last: list.last?.at)
    }

    /// Marks every record `matching` picks as deleted at `date` by `deviceID`. Records already deleted
    /// keep their first delete.
    /// - Returns: how many records were deleted now.
    @discardableResult
    public mutating func forget(at date: Date, by deviceID: String, where matching: (Record) -> Bool) -> Int {
        var count = 0
        for index in records.indices where records[index].deletedAt == nil && matching(records[index]) {
            records[index].deletedAt = date
            records[index].updatedAt = date
            records[index].updatedBy = deviceID
            count += 1
        }
        return count
    }
}

/// The companion's day that contains a date, for deleting one day of records.
public struct MemoryDay: Equatable, Sendable {
    public let start: Date
    public let end: Date

    /// The day containing `date`, which starts at the same hour as the rest of the app's days.
    public init(containing date: Date, calendar: Calendar = .current) {
        start = StateEngine.dayStart(for: date, calendar: calendar)
        end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
    }

    /// Whether `date` falls in this day.
    public func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }
}
