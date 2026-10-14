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
}
