import Foundation
import Testing

@testable import HubCore

@Suite struct CommuteTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    // 2026-10-07 is a Wednesday, 10-10 a Saturday.
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    func presence(stay kind: HubPlace.Kind, from start: Date, leave: Date) -> PlacePresence {
        var presence = PlacePresence()
        presence.record(kind, entered: true, at: start)
        presence.record(kind, entered: false, at: leave)
        return presence
    }

    func phase(
        _ presence: PlacePresence,
        mode: Mode? = .chill,
        motion: [MotionSample] = [],
        at now: Date
    ) -> CommutePhase? {
        CommuteEngine.phase(presence: presence, mode: mode, motion: motion, now: now, calendar: calendar)
    }

    @Test func leavingHomeOnAWorkDayWalksToWork() {
        let home = presence(stay: .home, from: date(6, 19), leave: date(7, 8, 30))
        #expect(phase(home, at: date(7, 8, 35)) == CommutePhase(leg: .toWork, stage: .walking, since: date(7, 8, 30)))
        #expect(phase(home, at: date(7, 8, 29)) == nil)
        #expect(phase(home, at: date(7, 10, 31)) == nil)
    }

    @Test func theTrainAndTheWalkAfterIt() {
        let home = presence(stay: .home, from: date(6, 19), leave: date(7, 8, 30))
        let motion = [
            MotionSample(kind: .walking, start: date(7, 8, 30)),
            MotionSample(kind: .transit, start: date(7, 8, 40)),
            MotionSample(kind: .unclear, start: date(7, 8, 50)),
            MotionSample(kind: .walking, start: date(7, 9, 10)),
        ]
        #expect(phase(home, motion: motion, at: date(7, 8, 55))?.stage == .onTransit)
        #expect(phase(home, motion: motion, at: date(7, 8, 55))?.since == date(7, 8, 40))
        let walk = CommutePhase(leg: .toWork, stage: .walking, since: date(7, 9, 10))
        #expect(phase(home, motion: motion, at: date(7, 9, 15)) == walk)
    }

    @Test func arrivingAnywhereEndsIt() {
        var home = presence(stay: .home, from: date(6, 19), leave: date(7, 8, 30))
        home.record(.fitness, entered: true, at: date(7, 9, 20))
        #expect(phase(home, at: date(7, 9, 21)) == nil)
    }

    @Test func arrivingAtTheOtherEndShowsForThreeMinutes() {
        var trip = presence(stay: .home, from: date(6, 19), leave: date(7, 8, 30))
        trip.record(.office, entered: true, at: date(7, 9, 20))
        let arrived = CommutePhase(leg: .toWork, stage: .arrived, since: date(7, 9, 20))
        #expect(phase(trip, mode: .work, at: date(7, 9, 21)) == arrived)
        #expect(phase(trip, mode: .work, at: date(7, 9, 24)) == nil)
        var back = presence(stay: .office, from: date(7, 9), leave: date(7, 18))
        back.record(.home, entered: true, at: date(7, 18, 40))
        #expect(phase(back, at: date(7, 18, 41)) == CommutePhase(leg: .home, stage: .arrived, since: date(7, 18, 40)))
    }

    @Test func weekendsAndLunchAreNoCommute() {
        let saturday = presence(stay: .home, from: date(9, 19), leave: date(10, 11))
        #expect(phase(saturday, at: date(10, 11, 5)) == nil)
        let lunch = presence(stay: .office, from: date(7, 9), leave: date(7, 12))
        #expect(phase(lunch, mode: .work, at: date(7, 12, 5)) == nil)
        let evening = presence(stay: .office, from: date(7, 9), leave: date(7, 18))
        let home = CommutePhase(leg: .home, stage: .walking, since: date(7, 18))
        #expect(phase(evening, mode: .chill, at: date(7, 18, 5)) == home)
    }

    @Test func aPassByIsNoCommute() {
        let passBy = presence(stay: .home, from: date(7, 8, 29), leave: date(7, 8, 30))
        #expect(phase(passBy, at: date(7, 8, 35)) == nil)
    }
}
