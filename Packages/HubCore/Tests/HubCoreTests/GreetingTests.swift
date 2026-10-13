import Foundation
import Testing

@testable import HubCore

@Suite struct GreetingTests {
    @Test func theGreetingFollowsTheHour() {
        #expect(Greeting.text(hour: 8, name: nil) == "GOOD MORNING")
        #expect(Greeting.text(hour: 13, name: "") == "GOOD AFTERNOON")
        #expect(Greeting.text(hour: 23, name: "AYA") == "GOOD EVENING, AYA")
        #expect(Greeting.text(hour: 3, name: nil) == "GOOD EVENING")
    }

    @Test func aNewInstallHasNoName() throws {
        let suite = "GreetingTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        Greeting.adopt(in: defaults, existingInstall: false)
        #expect(Greeting.name(in: defaults) == nil)
        // Records saved later don't bring the old name back.
        Greeting.adopt(in: defaults, existingInstall: true)
        #expect(Greeting.name(in: defaults) == nil)
    }

    @Test func anInstallWithRecordsKeepsItsNameOnce() throws {
        let suite = "GreetingTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        Greeting.adopt(in: defaults, existingInstall: true)
        #expect(Greeting.name(in: defaults) == Greeting.legacyName)
        defaults.removeObject(forKey: Greeting.nameKey)
        Greeting.adopt(in: defaults, existingInstall: true)
        #expect(Greeting.name(in: defaults) == nil)
    }
}
