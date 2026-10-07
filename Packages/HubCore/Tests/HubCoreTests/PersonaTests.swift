import Foundation
import Testing

@testable import HubCore

@Suite struct PersonaTests {
    @Test func defaultsToHakuAndKeepsWhatWasStored() throws {
        let defaults = try #require(UserDefaults(suiteName: "persona-\(UUID().uuidString)"))
        #expect(Persona.stored(in: defaults) == .haku)
        Persona.kuro.store(in: defaults)
        #expect(Persona.stored(in: defaults) == .kuro)
        defaults.set("someone-else", forKey: Persona.defaultsKey)
        #expect(Persona.stored(in: defaults) == .haku)
    }

    @Test func kuroRenamesOnlyHerOwnSlots() {
        #expect(Mode.boxing.title(for: .kuro) == "网球日")
        #expect(Mode.money.title(for: .kuro) == "备课")
        #expect(Mode.work.title(for: .kuro) == Mode.work.title)
        #expect(Mode.chill.title(for: .kuro) == Mode.chill.title)
        for mode in Mode.allCases {
            #expect(mode.title(for: .haku) == mode.title)
        }
    }

    @Test func kuroCallsTheGymATennisCourt() {
        #expect(HubPlace.Kind.gym.title(for: .kuro) == "网球场")
        #expect(HubPlace.Kind.office.title(for: .kuro) == HubPlace.Kind.office.title)
        #expect(HubPlace.Kind.gym.title(for: .haku) == HubPlace.Kind.gym.title)
        #expect(HubPlace.Action.boxing.title(for: .kuro) == "当网球场")
        #expect(HubPlace.Action.work.title(for: .kuro) == HubPlace.Action.work.title)
        #expect(HubPlace.Action.boxing.title(for: .haku) == HubPlace.Action.boxing.title)
        #expect(Persona.allCases.map(\.title) == ["HAKU", "KURO"])
    }

    @Test func kuroIsAtTheTennisCourtNotTheBoxingGym() {
        #expect(CompanionActivity.boxingAtGym.reason(for: .kuro) == "你在网球场")
        #expect(CompanionActivity.running.reason(for: .kuro) == CompanionActivity.running.reason)
        for activity in [CompanionActivity.boxingAtGym, .gymSession, .running, .gymDay, .runDay] {
            #expect(activity.reason(for: .haku) == activity.reason)
        }
    }
}
