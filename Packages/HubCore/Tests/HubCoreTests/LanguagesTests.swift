import Foundation
import Testing

@testable import HubCore

@Suite(.serialized) struct LanguagesTests {
    // Issue #350: code that never loads a choice keeps the Chinese source text.
    @Test func chineseUntilLoaded() {
        #expect(!Languages.isOn)
        #expect(Languages.locale == Languages.chinese)
        #expect("拳击日".localized == "拳击日")
        #expect("又上班。".localized(for: .haku) == "又上班。")
    }

    // These read the defaults without loading them, so other suites running at the same time keep Chinese.
    @Test func aNewInstallFollowsThePhoneAndAPickIsKept() throws {
        let defaults = try #require(UserDefaults(suiteName: "languages-\(UUID().uuidString)"))
        #expect(Languages.stored(in: defaults) == .system)
        defaults.set(Languages.Choice.japanese.rawValue, forKey: Languages.key)
        #expect(Languages.stored(in: defaults) == .japanese)
        defaults.set("klingon", forKey: Languages.key)
        #expect(Languages.stored(in: defaults) == .system)
        #expect(Languages.Choice.system.language == nil)
        #expect(Languages.Choice.english.language == .english)
    }

    @Test func eachLanguageReadsItsOwnStrings() {
        func title(_ language: Languages.Language) -> String {
            String(localized: "拳击日", table: "Localizable", bundle: Languages.bundle(.module, for: language))
        }
        #expect(title(.japanese) == "ボクシング")
        #expect(title(.english) == "Boxing")
    }

    @Test func thePhonesFirstKnownLanguageWins() {
        #expect(Languages.language(for: ["fr-FR", "ja-JP", "en-US"]) == .japanese)
        #expect(Languages.language(for: ["zh-Hant-TW"]) == .chinese)
        #expect(Languages.language(for: ["en-GB", "zh-Hans-CN"]) == .english)
        #expect(Languages.language(for: ["fr-FR", "de-DE"]) == .english)
        #expect(Languages.language(for: []) == .english)
    }

    @Test func weekStartsWhereThePhoneSays() {
        #expect(Languages.weekCalendar(firstWeekday: 2).weekdaysInOrder == [2, 3, 4, 5, 6, 7, 1])
        #expect(Languages.weekCalendar(firstWeekday: 1).weekdaysInOrder == [1, 2, 3, 4, 5, 6, 7])
    }

    @Test func weekdayNamesFollowTheChoice() {
        Languages.choice = .chinese
        let chinese = Languages.weekCalendar(firstWeekday: 2)
        // Index 1 is Monday.
        #expect(chinese.veryShortWeekdaySymbols[1] == "一")
        #expect(chinese.standaloneWeekdaySymbols[1] == "星期一")
        #expect(Languages.weekCalendar().weekdaysInOrder.first == 2)
    }
}
