import Foundation
import Testing

@testable import HubCore

@Suite struct PlaceWalkTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    let cafePlace = HubPlace.custom(name: "咖啡店", action: .chill, latitude: 0, longitude: 0, id: "customA")

    func at(_ minutes: Double) -> Date {
        start.addingTimeInterval(minutes * 60)
    }

    func leaving(_ kind: HubPlace.Kind, stayed minutes: Double = 60) -> PlacePresence {
        var presence = PlacePresence()
        presence.record(kind, entered: true, at: at(-minutes))
        presence.record(kind, entered: false, at: at(0))
        return presence
    }

    @Test func walksForHalfAnHourAfterLeaving() {
        for kind in PlaceWalk.places {
            let presence = leaving(kind)
            #expect(PlaceWalk.walk(in: presence, now: at(0)) == PlaceWalk(from: kind, since: at(0)))
            #expect(PlaceWalk.walk(in: presence, now: at(29))?.from == kind)
            #expect(PlaceWalk.walk(in: presence, now: at(30)) == nil)
        }
        #expect(PlaceWalk(from: .home, since: at(0)).until == at(30))
        #expect(PlaceWalk.walk(in: PlacePresence(), now: at(0)) == nil)
    }

    @Test func arrivingSomewhereEndsTheWalk() {
        var presence = leaving(.home)
        presence.record(.office, entered: true, at: at(20))
        #expect(PlaceWalk.walk(in: presence, now: at(10))?.from == .home)
        #expect(PlaceWalk.walk(in: presence, now: at(21)) == nil)
        var cafe = leaving(.office)
        cafe.record(cafePlace, entered: true, at: at(5))
        #expect(PlaceWalk.walk(in: cafe, now: at(6)) == nil)
    }

    @Test func theLatestLeaveWins() {
        var presence = leaving(.office)
        presence.record(.fitness, entered: true, at: at(10))
        presence.record(.fitness, entered: false, at: at(50))
        #expect(PlaceWalk.walk(in: presence, now: at(55)) == PlaceWalk(from: .fitness, since: at(50)))
    }

    @Test func passingByOrDriftIsNoWalk() {
        #expect(PlaceWalk.walk(in: leaving(.gym, stayed: 2), now: at(1)) == nil)
        var drift = leaving(.home)
        drift.record(.home, entered: true, at: at(1))
        #expect(PlaceWalk.walk(in: drift, now: at(2)) == nil)
    }

    @Test func addedPlacesDoNotStartAWalk() {
        var presence = PlacePresence()
        presence.record(cafePlace, entered: true, at: at(-60))
        presence.record(cafePlace, entered: false, at: at(0))
        #expect(PlaceWalk.walk(in: presence, now: at(1)) == nil)
    }
}
