import Foundation
import Testing

@testable import HubCore

@Suite struct PersonaTests {
    @Test func defaultsToHakuAndKeepsWhatWasStored() throws {
        let defaults = try #require(UserDefaults(suiteName: "persona-\(UUID().uuidString)"))
        #expect(Persona.stored(in: defaults) == .haku)
        Persona.partner.store(in: defaults)
        #expect(Persona.stored(in: defaults) == .partner)
        defaults.set("someone-else", forKey: Persona.defaultsKey)
        #expect(Persona.stored(in: defaults) == .haku)
    }

    @Test func partnerRenamesOnlyHerOwnSlots() {
        #expect(Mode.boxing.title(for: .partner) == "网球日")
        #expect(Mode.money.title(for: .partner) == "备课")
        #expect(Mode.work.title(for: .partner) == Mode.work.title)
        #expect(Mode.chill.title(for: .partner) == Mode.chill.title)
        for mode in Mode.allCases {
            #expect(mode.title(for: .haku) == mode.title)
        }
    }

    @Test func partnerCallsTheGymATennisCourt() {
        #expect(HubPlace.Kind.gym.title(for: .partner) == "网球场")
        #expect(HubPlace.Kind.office.title(for: .partner) == HubPlace.Kind.office.title)
        #expect(HubPlace.Kind.gym.title(for: .haku) == HubPlace.Kind.gym.title)
        #expect(HubPlace.Action.boxing.title(for: .partner) == "当网球场")
        #expect(HubPlace.Action.work.title(for: .partner) == HubPlace.Action.work.title)
        #expect(HubPlace.Action.boxing.title(for: .haku) == HubPlace.Action.boxing.title)
        #expect(Persona.allCases.map(\.title) == ["HAKU", "猫耳角色"])
    }
}
