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

    // Mike confirmed 23:30 on 2026-10-03. PM 2026-10-13 (写死作息排查 v0 #1): it only prefills the picker;
    // nothing follows a bedtime the user hasn't set.
    /// 23:30 to 05:00.
    public static let standard = BedtimeSchedule(startMinute: 23 * 60 + 30, endMinute: 5 * 60)

    // An empty window is never on, so the sleepy look, the good-night animation and the reminder stay off.
    /// No bedtime set yet.
    public static let unset = BedtimeSchedule(startMinute: 0, endMinute: 0)

    /// Whether the user set a bedtime.
    public var isSet: Bool { startMinute != endMinute }

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

extension BedtimeSchedule {
    static let defaultsKey = "bedtimeSchedule"

    /// The schedule saved in `defaults`, or `.unset` when none is saved or it can't be read.
    public static func stored(in defaults: UserDefaults) -> BedtimeSchedule {
        guard let data = defaults.data(forKey: defaultsKey) else { return .unset }
        return (try? JSONDecoder().decode(BedtimeSchedule.self, from: data)) ?? .unset
    }

    static let adoptedKey = "bedtimeAdopted"
    static let reminderKey = "bedtimeReminder"

    // PM 2026-10-13 (onboarding 文案 v0 §4a): the reminder is off until the user turns it on.
    /// Whether the bedtime reminder is on in `defaults`.
    public static func remindsAtBedtime(in defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: reminderKey)
    }

    /// Turns the bedtime reminder on or off in `defaults`.
    public static func setRemindsAtBedtime(_ on: Bool, in defaults: UserDefaults) {
        defaults.set(on, forKey: reminderKey)
    }

    // Installs from before 2026-10-13 used `.standard` without saving it. Saving it once keeps their bedtime;
    // a new install has no records on its first launch and stays unset.
    /// For an install that had records before bedtimes had to be set, once: saves `.standard` as its bedtime
    /// when none is saved, and keeps its reminder on.
    /// - Parameter existingInstall: whether this install already has records.
    public static func adoptStandard(in defaults: UserDefaults, existingInstall: Bool) {
        guard !defaults.bool(forKey: adoptedKey) else { return }
        defaults.set(true, forKey: adoptedKey)
        guard existingInstall else { return }
        setRemindsAtBedtime(true, in: defaults)
        if defaults.data(forKey: defaultsKey) == nil { BedtimeSchedule.standard.store(in: defaults) }
    }

    /// Saves the schedule in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }

    /// The reminder time as hour and minute.
    public var startComponents: DateComponents {
        DateComponents(hour: startMinute / 60, minute: startMinute % 60)
    }

    /// When the daily reminder fires: `startComponents` while `on` and a bedtime is set, else `nil`.
    public func reminderTime(on: Bool) -> DateComponents? {
        on && isSet ? startComponents : nil
    }
}
