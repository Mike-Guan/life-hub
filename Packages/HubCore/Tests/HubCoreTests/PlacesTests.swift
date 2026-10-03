import Foundation
import Testing

@testable import HubCore

@Suite struct PlacesTests {
    @Test func placesMapToTriggers() {
        #expect(HubPlace.Kind.gym.trigger(entered: true) == .enteredGym)
        #expect(HubPlace.Kind.gym.trigger(entered: false) == .leftGym)
        #expect(HubPlace.Kind.office.trigger(entered: true) == .enteredOffice)
        #expect(HubPlace.Kind.office.trigger(entered: false) == nil)
        #expect(Set(HubPlace.Kind.allCases.map(\.title)).count == 2)
    }

    @Test func subscriptSetsReplacesAndRemoves() {
        var settings = PlaceSettings()
        settings[.gym] = HubPlace(kind: .gym, latitude: 1, longitude: 2)
        settings[.gym] = HubPlace(kind: .gym, latitude: 3, longitude: 4)
        #expect(settings.places.count == 1)
        #expect(settings[.gym]?.latitude == 3)
        #expect(settings[.gym]?.radius == HubPlace.defaultRadius)
        #expect(settings[.office] == nil)
        settings[.gym] = nil
        #expect(settings.places.isEmpty)
    }

    @Test func storedSettingsRoundTripAndFallBack() throws {
        let suite = "lifehub-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(PlaceSettings.stored(in: defaults) == PlaceSettings())

        let settings = PlaceSettings(places: [HubPlace(kind: .office, latitude: 35.6, longitude: 139.7)])
        settings.store(in: defaults)
        #expect(PlaceSettings.stored(in: defaults) == settings)

        defaults.set(Data("bad".utf8), forKey: "places")
        #expect(PlaceSettings.stored(in: defaults) == PlaceSettings())
    }
}
