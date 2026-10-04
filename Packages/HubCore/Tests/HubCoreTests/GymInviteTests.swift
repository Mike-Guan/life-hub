import Foundation
import Testing

@testable import HubCore

@Suite struct GymInviteTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    // 2026-10-05 is a Monday, 2026-10-06 a Tuesday (a gym day).
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    func need(_ signals: NeedSignals, at now: Date) -> NeedReading? {
        NeedEngine.need(signals, now: now, calendar: calendar)
    }

    func home(_ day: Int) -> NeedSignals {
        NeedSignals(atHomeSince: date(day, 18, 50), homeKnown: true)
    }

    @Test func gymDayEveningAtHomeIsTheInvite() throws {
        let reading = try #require(need(home(6), at: date(6, 19, 45)))
        #expect(reading.need == .gymDay)
        #expect(reading.since == date(6, 19, 30))
        #expect(reading.until == date(6, 20, 30))
        #expect(!reading.reasons.isEmpty)
        // Outside the window, on a Monday, or away from home: nothing.
        #expect(need(home(6), at: date(6, 19, 29)) == nil)
        #expect(need(home(6), at: date(6, 20, 30)) == nil)
        #expect(need(home(5), at: date(5, 19, 45)) == nil)
        #expect(need(NeedSignals(homeKnown: true), at: date(6, 19, 45)) == nil)
        #expect(need(NeedSignals(), at: date(6, 19, 45)) == nil)
    }

    @Test func trainingOrTheGymEndsTheInvite() {
        var trained = home(6)
        let lift = WorkoutSummary(id: "lift", kind: .strength, start: date(6, 7), end: date(6, 8))
        trained.workouts = [lift]
        #expect(need(trained, at: date(6, 19, 45)) == nil)
        // A run doesn't count as the gym.
        trained.workouts = [WorkoutSummary(id: "run", kind: .running, start: date(6, 7), end: date(6, 8))]
        #expect(need(trained, at: date(6, 19, 45))?.need == .gymDay)

        var visited = home(6)
        visited.fitnessSeenAt = date(6, 12)
        #expect(need(visited, at: date(6, 19, 45)) == nil)
        visited.fitnessSeenAt = date(5, 20)
        #expect(need(visited, at: date(6, 19, 45))?.need == .gymDay)

        var going = home(6)
        going.departing = true
        #expect(need(going, at: date(6, 19, 45)) == nil)
    }

    @Test func gymInviteReplacesCouchScrolling() {
        var scrolling = home(6)
        scrolling.scrollThresholdAt = date(6, 19, 40)
        #expect(need(scrolling, at: date(6, 19, 50))?.need == .gymDay)
        #expect(need(scrolling, at: date(6, 20, 31))?.need == nil)
        scrolling.scrollSeenAt = date(6, 20, 25)
        #expect(need(scrolling, at: date(6, 20, 31))?.need == .couchScroll)
    }

    @Test func inviteGoesOutAtEightOncePerDay() {
        let reading = need(home(6), at: date(6, 19, 35))
        let now = date(6, 19, 35)
        let calendar = calendar
        let time = { (last: Date?) in
            NeedEngine.inviteTime(for: reading, now: now, lastInviteAt: last, bedtime: .standard, calendar: calendar)
        }
        #expect(time(nil) == date(6, 20))
        // A couch invite earlier today was the day's one invite.
        #expect(time(date(6, 19, 10)) == nil)
        #expect(NeedEngine.inviteText(for: .gymDay).count <= 14)
    }

    @Test func departureEndsAfterAnHourOrAtTheGym() {
        let walk = GymDeparture(at: date(6, 20))
        let none = PlacePresence()
        #expect(!walk.isActive(at: date(6, 19, 59), presence: none))
        #expect(walk.isActive(at: date(6, 20, 59), presence: none))
        #expect(!walk.isActive(at: date(6, 21), presence: none))

        var there = PlacePresence()
        there.record(.fitness, entered: true, at: date(6, 20, 15))
        #expect(!walk.isActive(at: date(6, 20, 20), presence: there))
        there.record(.fitness, entered: false, at: date(6, 20, 40))
        #expect(!walk.isActive(at: date(6, 20, 45), presence: there))
        // Leaving the gym before saying 走 doesn't end the walk.
        var earlier = PlacePresence()
        earlier.record(.fitness, entered: true, at: date(6, 12))
        earlier.record(.fitness, entered: false, at: date(6, 13))
        #expect(walk.isActive(at: date(6, 20, 10), presence: earlier))
    }

    @Test func gymMomentReplacesOnlyTheBag() {
        #expect(GymDeparture.moment(activity: .gymDay, need: .gymDay, departing: false) == .gymInvite)
        #expect(GymDeparture.moment(activity: .gymDay, need: nil, departing: true) == .heading)
        #expect(GymDeparture.moment(activity: nil, need: nil, departing: true) == .heading)
        #expect(GymDeparture.moment(activity: .gymDay, need: nil, departing: false) == nil)
        #expect(GymDeparture.moment(activity: .gymSession, need: nil, departing: true) == nil)
        #expect(GymDeparture.moment(activity: .runDay, need: .gymDay, departing: false) == nil)
    }

    @Test func departurePersists() throws {
        let suite = "lifehub-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(GymDeparture.stored(in: defaults) == nil)
        GymDeparture(at: date(6, 20)).store(in: defaults)
        #expect(GymDeparture.stored(in: defaults) == GymDeparture(at: date(6, 20)))
    }
}
