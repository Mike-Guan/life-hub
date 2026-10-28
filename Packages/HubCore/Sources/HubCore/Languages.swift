import Foundation
import Synchronization

// Issue #350. The app follows the phone's language unless the user picks one in Settings. Chinese is the
// source: its text is the key itself, so it needs no lookup. A language the app has no strings for falls
// back to English, the friends test's second language.
/// The language the app shows: the phone's, or the one the user picked.
public enum Languages {
    /// A language the app has strings for.
    public enum Language: String, CaseIterable, Sendable {
        case chinese = "zh-Hans"
        case japanese = "ja"
        case english = "en"

        /// The language's name in itself, for the picker.
        public var name: String {
            switch self {
            case .chinese: "中文"
            case .japanese: "日本語"
            case .english: "English"
            }
        }
    }

    /// The user's choice in Settings.
    public enum Choice: String, CaseIterable, Sendable {
        /// Follows the phone's language.
        case system
        case chinese
        case japanese
        case english

        /// The language picked, `nil` when the choice follows the phone.
        public var language: Language? {
            switch self {
            case .system: nil
            case .chinese: .chinese
            case .japanese: .japanese
            case .english: .english
            }
        }
    }

    /// The user defaults key for the choice.
    public static let key = "languages.choice"

    // Chinese until `load(from:)` runs, so code that never loads a choice (tests, previews) keeps the source text.
    private static let current = Mutex(Choice.chinese)

    /// The user's choice.
    public static var choice: Choice {
        get { current.withLock { $0 } }
        set { current.withLock { $0 = newValue } }
    }

    /// Reads the choice from `defaults`; the phone's language when none is saved.
    public static func load(from defaults: UserDefaults) {
        choice = stored(in: defaults)
    }

    /// The choice saved in `defaults`; the phone's language when none is saved.
    public static func stored(in defaults: UserDefaults) -> Choice {
        defaults.string(forKey: key).flatMap(Choice.init(rawValue:)) ?? .system
    }

    /// Saves `choice` in `defaults` and uses it from now on.
    public static func store(_ choice: Choice, in defaults: UserDefaults) {
        defaults.set(choice.rawValue, forKey: key)
        self.choice = choice
    }

    /// The language the app shows now.
    public static var language: Language {
        choice.language ?? language(for: Locale.preferredLanguages)
    }

    /// The first of `preferred` the app has strings for, English when none.
    /// - Parameter preferred: language identifiers in the phone's order, such as `Locale.preferredLanguages`.
    public static func language(for preferred: [String]) -> Language {
        for identifier in preferred {
            switch Locale.Language(identifier: identifier).languageCode {
            case .chinese: return .chinese
            case .japanese: return .japanese
            case .english: return .english
            default: continue
            }
        }
        return .english
    }

    /// `true` when text is looked up in a translation; `false` for Chinese, the source text.
    public static var isOn: Bool { language != .chinese }

    /// Simplified Chinese, the source language.
    public static let chinese = Locale(identifier: Language.chinese.rawValue)

    /// The locale views look up their text in: the shown language with the phone's region.
    public static var locale: Locale {
        let language = language
        guard language != .chinese else { return chinese }
        let phone = Locale.autoupdatingCurrent
        if phone.language.languageCode == Locale.Language(identifier: language.rawValue).languageCode {
            return phone
        }
        guard let region = phone.region?.identifier else { return Locale(identifier: language.rawValue) }
        return Locale(identifier: "\(language.rawValue)_\(region)")
    }

    // Bundle(path:) returns the same instance for a path, so looking it up on every string is cheap.
    /// The part of `bundle` that holds the shown language's strings, or `bundle` itself when it has none.
    public static func bundle(_ bundle: Bundle) -> Bundle {
        self.bundle(bundle, for: language)
    }

    static func bundle(_ bundle: Bundle, for language: Language) -> Bundle {
        bundle.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? bundle
    }

    /// A Gregorian calendar whose weekday names are in `locale` and whose week starts on `firstWeekday`.
    /// - Parameter firstWeekday: The first day of the week, as a `Calendar` weekday (1 is Sunday). Defaults to
    ///   the phone's outside Chinese, and Monday in Chinese.
    public static func weekCalendar(firstWeekday: Int? = nil) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        // Chinese weeks start on Monday, whatever region the phone is set to.
        calendar.firstWeekday = firstWeekday ?? (isOn ? Calendar.current.firstWeekday : 2)
        return calendar
    }
}

extension Calendar {
    /// The seven weekdays in display order, starting on `firstWeekday` (1 is Sunday).
    public var weekdaysInOrder: [Int] {
        (0..<7).map { (firstWeekday - 1 + $0) % 7 + 1 }
    }
}
