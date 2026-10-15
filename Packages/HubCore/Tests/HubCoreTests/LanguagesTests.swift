import Foundation
import Testing

@testable import HubCore

@Suite(.serialized) struct LanguagesTests {
    // Issue #350: Japanese and English stay off until every string is in, whatever the phone's language.
    @Test func offUntilTurnedOn() throws {
        let defaults = try #require(UserDefaults(suiteName: "languages-\(UUID().uuidString)"))
        Languages.load(from: defaults)
        #expect(!Languages.isOn)
        #expect(Languages.locale == Languages.chinese)
        #expect("拳击日".localized == "拳击日")
        #expect("又上班。".localized(for: .haku) == "又上班。")
    }

    @Test func switchIsReadFromDefaults() throws {
        let defaults = try #require(UserDefaults(suiteName: "languages-\(UUID().uuidString)"))
        defaults.set(true, forKey: Languages.key)
        Languages.load(from: defaults)
        defer { Languages.isOn = false }
        #expect(Languages.isOn)
        #expect(Languages.locale.identifier == Locale.autoupdatingCurrent.identifier)
    }

    @Test func weekStartsWhereThePhoneSays() {
        #expect(Languages.weekCalendar(firstWeekday: 2).weekdaysInOrder == [2, 3, 4, 5, 6, 7, 1])
        #expect(Languages.weekCalendar(firstWeekday: 1).weekdaysInOrder == [1, 2, 3, 4, 5, 6, 7])
    }

    @Test func weekdayNamesFollowTheSwitch() {
        Languages.isOn = false
        let chinese = Languages.weekCalendar(firstWeekday: 2)
        // Index 1 is Monday.
        #expect(chinese.veryShortWeekdaySymbols[1] == "一")
        #expect(chinese.standaloneWeekdaySymbols[1] == "星期一")
    }
}
