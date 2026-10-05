import Foundation
import Testing

@testable import HubCore

@Suite struct PlacesTests {
    @Test func placesMapToTriggers() {
        #expect(HubPlace.Kind.gym.trigger(entered: true) == .enteredGym)
        #expect(HubPlace.Kind.gym.trigger(entered: false) == .leftGym)
        #expect(HubPlace.Kind.office.trigger(entered: true) == .enteredOffice)
        #expect(HubPlace.Kind.office.trigger(entered: false) == .leftOffice)
        #expect(HubPlace.Kind.home.trigger(entered: true) == nil)
        #expect(HubPlace.Kind.home.trigger(entered: false) == nil)
        #expect(HubPlace.Kind.fitness.trigger(entered: true) == nil)
        #expect(HubPlace.Kind.fitness.trigger(entered: false) == nil)
        #expect(Set(HubPlace.Kind.presets.map(\.title)).count == 4)
    }

    @Test func addedPlacesActLikeTheirAction() {
        let gym = HubPlace.custom(name: "第二健身房", action: .fitness, latitude: 1, longitude: 2, id: "customA")
        #expect(gym.presenceKeys == ["customA", "fitness"])
        #expect(gym.trigger(entered: true) == nil)
        let boxing = HubPlace.custom(name: "拳馆二", action: .boxing, latitude: 1, longitude: 2, id: "customB")
        #expect(boxing.presenceKeys == ["customB", "gym"])
        #expect(boxing.trigger(entered: true) == .enteredGym)
        #expect(boxing.trigger(entered: false) == .leftGym)
        let studio = HubPlace.custom(name: "工作室", action: .sideHustle, latitude: 1, longitude: 2, id: "customC")
        #expect(studio.presenceKeys == ["customC"])
        #expect(studio.trigger(entered: true) == .enteredPlace(.money, name: "工作室"))
        #expect(studio.trigger(entered: false) == nil)
        let park = HubPlace.custom(name: "公园", action: .chill, latitude: 1, longitude: 2)
        #expect(park.trigger(entered: true) == .enteredPlace(.chill, name: "公园"))
        #expect(park.id.hasPrefix("custom"))
        #expect(park.id.allSatisfy { $0.isLetter || $0.isNumber })
        let note = HubPlace.custom(name: "书店", action: .recordOnly, latitude: 1, longitude: 2)
        #expect(note.trigger(entered: true) == nil)
        let office = HubPlace.custom(name: "分公司", action: .work, latitude: 1, longitude: 2)
        #expect(office.trigger(entered: true) == .enteredOffice)
        #expect(office.trigger(entered: false) == .leftOffice)
        #expect(HubPlace(kind: .office, latitude: 1, longitude: 2).trigger(entered: true) == .enteredOffice)
        #expect(HubPlace(kind: .fitness, latitude: 1, longitude: 2).presenceKeys == ["fitness"])
        #expect(Set(HubPlace.Action.allCases.map(\.title)).count == HubPlace.Action.allCases.count)
    }

    @Test func placesSavedBeforeAddedPlacesStillDecode() throws {
        let old = Data(#"{"places":[{"kind":"gym","latitude":1,"longitude":2,"radius":120}]}"#.utf8)
        let settings = try JSONDecoder().decode(PlaceSettings.self, from: old)
        let gym = try #require(settings[.gym])
        #expect(gym.id == "gym")
        #expect(gym.action == .boxing)
        #expect(gym.name == nil)
        #expect(gym.radius == 120)
        #expect(gym.title == "拳馆")
    }

    @Test func addedPlacesStopAtTheRegionLimit() {
        var settings = PlaceSettings()
        for index in 0..<PlaceSettings.limit {
            let saved = settings.save(.custom(name: "\(index)", action: .recordOnly, latitude: 0, longitude: 0))
            #expect(saved)
        }
        #expect(!settings.canAdd)
        let extra = settings.save(.custom(name: "多一个", action: .recordOnly, latitude: 0, longitude: 0))
        #expect(!extra)
        var first = settings.places[0]
        first.name = "改名"
        let renamed = settings.save(first)
        #expect(renamed)
        #expect(settings.places[0].title == "改名")
        settings.remove(id: first.id)
        #expect(settings.canAdd)
        #expect(settings.custom.count == PlaceSettings.limit - 1)
    }

    @Test func removedPlacesAreLeft() {
        let at = Date(timeIntervalSince1970: 1_790_000_000)
        let gym = HubPlace.custom(name: "健身", action: .fitness, latitude: 0, longitude: 0, id: "customA")
        var presence = PlacePresence()
        presence.record(gym, entered: true, at: at)
        presence.record(.home, entered: true, at: at)
        #expect(presence.since(.fitness) == at)
        #expect(presence.since(key: "customA") == at)
        let settings = PlaceSettings(places: [HubPlace(kind: .home, latitude: 0, longitude: 0)])
        presence.leaveAll(except: settings.presenceKeys, at: at.addingTimeInterval(60))
        #expect(presence.since(.fitness) == nil)
        #expect(presence.left(.fitness) == at.addingTimeInterval(60))
        #expect(presence.since(.home) == at)
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

    @Test func presenceKeepsTheFirstArrivalAndClearsOnLeaving() {
        var presence = PlacePresence()
        let first = Date(timeIntervalSince1970: 1_790_000_000)
        presence.record(.home, entered: true, at: first)
        presence.record(.home, entered: true, at: first.addingTimeInterval(600))
        #expect(presence.since(.home) == first)
        #expect(presence.since(.gym) == nil)
        presence.record(.home, entered: false, at: first.addingTimeInterval(900))
        #expect(presence.since(.home) == nil)
    }

    @Test func storedPresenceRoundTripsAndFallsBack() throws {
        let suite = "lifehub-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(PlacePresence.stored(in: defaults) == PlacePresence())

        var presence = PlacePresence()
        presence.record(.gym, entered: true, at: Date(timeIntervalSince1970: 1_790_000_000))
        presence.store(in: defaults)
        #expect(PlacePresence.stored(in: defaults) == presence)

        defaults.set(Data("bad".utf8), forKey: "presence")
        #expect(PlacePresence.stored(in: defaults) == PlacePresence())
    }
}
