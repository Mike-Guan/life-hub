import Foundation
import Synchronization

// Issue #350. Japanese and English reach main in batches. Until all of them are in and reviewed, every build
// shows Chinese whatever the phone's language, so nobody sees a half-translated app. Debug and STG builds can
// turn the other languages on by hand.
/// Whether the app shows Japanese and English, or Chinese only.
public enum Languages {
    /// The user defaults key for the switch.
    public static let key = "languages.on"

    private static let on = Mutex(false)

    /// `true` when text follows the phone's language; `false` keeps Chinese.
    public static var isOn: Bool {
        get { on.withLock { $0 } }
        set { on.withLock { $0 = newValue } }
    }

    /// Reads the switch from `defaults` (off when never set).
    public static func load(from defaults: UserDefaults) {
        isOn = defaults.bool(forKey: key)
    }

    /// Simplified Chinese, the source language.
    public static let chinese = Locale(identifier: "zh-Hans")

    /// The locale views look up their text in: the phone's when on, Chinese when off.
    public static var locale: Locale {
        isOn ? .autoupdatingCurrent : chinese
    }

    /// A Gregorian calendar whose weekday names are in `locale` and whose week starts on `firstWeekday`.
    /// - Parameter firstWeekday: The first day of the week, as a `Calendar` weekday (1 is Sunday).
    public static func weekCalendar(firstWeekday: Int = Calendar.current.firstWeekday) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.firstWeekday = firstWeekday
        return calendar
    }
}

extension Calendar {
    /// The seven weekdays in display order, starting on `firstWeekday` (1 is Sunday).
    public var weekdaysInOrder: [Int] {
        (0..<7).map { (firstWeekday - 1 + $0) % 7 + 1 }
    }
}
