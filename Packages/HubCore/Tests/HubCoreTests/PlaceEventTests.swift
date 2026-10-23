import Foundation
import Testing

@testable import HubCore

// Each case is an arrival made while the app was closed and replayed at the next launch.
@MainActor
@Suite struct PlaceEventTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    // Wednesday 2026-10-21.
    func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: hour, minute: minute))!
    }

    let home = HubPlace(kind: .home, latitude: 1, longitude: 1)
    let office = HubPlace(kind: .office, latitude: 2, longitude: 2)
    let gym = HubPlace(kind: .gym, latitude: 3, longitude: 3)
    let fitness = HubPlace(kind: .fitness, latitude: 4, longitude: 4)
    let cafe = HubPlace.custom(name: "Cafe", action: .sideHustle, latitude: 5, longitude: 5, id: "customcafe")

    /// A store in `mode` since 06:00 and a presence that left home at 08:00.
    func commuting(in mode: Mode) -> (ModeStore, PlacePresence) {
        let store = ModeStore(fileURL: nil, deviceID: "test")
        store.switchTo(mode, source: .location, at: at(6))
        var presence = PlacePresence()
        presence.record(home, entered: true, at: at(6))
        presence.record(home, entered: false, at: at(8))
        return (store, presence)
    }

    func apply(_ event: PlaceEvent, _ store: ModeStore, _ presence: PlacePresence) -> PlaceEvent.Applied? {
        event.apply(
            to: presence, store: store, rules: .standard, cards: .legacy(for: .haku), persona: .haku,
            now: at(10), calendar: calendar
        )
    }

    @Test(arguments: [Mode.chill, .boxing, .money])
    func officeArrivalSwitchesToWorkFromEveryMode(mode: Mode) throws {
        let (store, presence) = commuting(in: mode)
        let applied = try #require(apply(PlaceEvent(place: office, entered: true, date: at(9)), store, presence))
        #expect(applied.decision?.mode == .work)
        #expect(store.current == .work)
        // The arrival keeps its own time, so the commute and the walk end then.
        #expect(applied.after.since(.office) == at(9))
        #expect(PlaceWalk.walk(in: applied.after, now: at(10)) == nil)
        #expect(CommuteEngine.phase(presence: applied.after, mode: .work, motion: [], now: at(10)) == nil)
    }

    @Test(arguments: [Mode.work, .chill, .money])
    func boxingGymArrivalSwitchesToBoxing(mode: Mode) throws {
        let (store, presence) = commuting(in: mode)
        let applied = try #require(apply(PlaceEvent(place: gym, entered: true, date: at(9)), store, presence))
        #expect(applied.decision?.mode == .boxing)
    }

    @Test(arguments: [Mode.work, .money])
    func fitnessArrivalSwitchesToChill(mode: Mode) throws {
        let (store, presence) = commuting(in: mode)
        let applied = try #require(apply(PlaceEvent(place: fitness, entered: true, date: at(9)), store, presence))
        #expect(applied.decision?.mode == .chill)
    }

    @Test(arguments: [Mode.work, .chill, .boxing])
    func addedPlaceArrivalSwitchesToItsMode(mode: Mode) throws {
        let (store, presence) = commuting(in: mode)
        let applied = try #require(apply(PlaceEvent(place: cafe, entered: true, date: at(9)), store, presence))
        #expect(applied.decision?.mode == .money)
    }

    @Test func officeLeaveEndsWork() throws {
        let store = ModeStore(fileURL: nil, deviceID: "test")
        store.switchTo(.work, source: .location, at: at(6))
        var presence = PlacePresence()
        presence.record(office, entered: true, at: at(6))
        let applied = try #require(apply(PlaceEvent(place: office, entered: false, date: at(9)), store, presence))
        #expect(applied.decision?.mode == .chill)
        #expect(applied.after.left(.office) == at(9))
    }

    @Test func eventThePresenceShowsIsSkipped() {
        let (store, presence) = commuting(in: .chill)
        var arrived = presence
        arrived.record(office, entered: true, at: at(9))
        #expect(apply(PlaceEvent(place: office, entered: true, date: at(9)), store, arrived) == nil)
        // A fence reporting "outside" for a place Mike never arrived at changes nothing.
        #expect(apply(PlaceEvent(place: gym, entered: false, date: at(9)), store, presence) == nil)
        #expect(store.current == .chill)
    }

    @Test func modeChosenAfterTheMoveStays() throws {
        let (store, presence) = commuting(in: .chill)
        store.switchTo(.money, at: at(9, 30))
        let applied = try #require(apply(PlaceEvent(place: office, entered: true, date: at(9)), store, presence))
        #expect(applied.decision == nil)
        #expect(store.current == .money)
        #expect(applied.after.since(.office) == at(9))
    }

    @Test func addedFitnessPlaceIsKnownByItsOwnKey() {
        let lifting = HubPlace.custom(name: "Lift", action: .fitness, latitude: 6, longitude: 6, id: "customlift")
        var presence = PlacePresence()
        presence.record(fitness, entered: true, at: at(9))
        // The preset gym's stay doesn't mean Mike is at the added one.
        #expect(!PlaceEvent(place: lifting, entered: true, date: at(9)).isKnown(in: presence))
    }
}
