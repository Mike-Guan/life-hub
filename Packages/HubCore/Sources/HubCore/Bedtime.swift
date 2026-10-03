import Foundation

/// Whether it's past Mike's bedtime. An overlay on the current mode, not a mode.
public enum Bedtime: String, Codable, Sendable {
    case off
    case on
}

/// The nightly window in which `Bedtime` is `.on`. Times are minutes after local midnight.
public struct BedtimeSchedule: Codable, Equatable, Sendable {
    public var startMinute: Int
    public var endMinute: Int

    // Mike confirmed 23:30 on 2026-10-03.
    /// 23:30 to 05:00.
    public static let standard = BedtimeSchedule(startMinute: 23 * 60 + 30, endMinute: 5 * 60)

    public init(startMinute: Int, endMinute: Int) {
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    /// The state at `date` in `calendar`'s time zone.
    public func state(at date: Date, calendar: Calendar = .current) -> Bedtime {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if startMinute <= endMinute {
            return (startMinute..<endMinute).contains(minute) ? .on : .off
        }
        return minute >= startMinute || minute < endMinute ? .on : .off
    }
}

extension BedtimeSchedule {
    /// The first time after `date` at which the state flips.
    public func nextChange(after date: Date, calendar: Calendar = .current) -> Date? {
        var changes: [Date] = []
        for minute in [startMinute, endMinute] {
            let parts = DateComponents(hour: minute / 60, minute: minute % 60)
            if let next = calendar.nextDate(after: date, matching: parts, matchingPolicy: .nextTime) {
                changes.append(next)
            }
        }
        return changes.min()
    }
}
