import Foundation
import Testing

@testable import HubCore

@Suite struct ActivityTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    // 2026-10-06 is a Tuesday (gym day); 2026-10-10 is a Saturday (run day).
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    func activity(_ signals: ActivitySignals = ActivitySignals(), at now: Date) -> CompanionActivity? {
        ActivityEngine.activity(signals, now: now, calendar: calendar)
    }

    func workout(_ kind: WorkoutSummary.Kind, endingAt end: Date) -> WorkoutSummary {
        WorkoutSummary(id: "\(kind)-\(end)", kind: kind, start: end.addingTimeInterval(-3600), end: end)
    }

    @Test func gymDayStartsAfterWorkUntilTrained() {
        #expect(activity(at: date(6, 18)) == nil)
        #expect(activity(at: date(6, 18, 30)) == .gymDay)
        #expect(activity(at: date(6, 23, 30)) == nil)
        #expect(activity(at: date(9, 19)) == nil)

        let lifted = ActivitySignals(workouts: [workout(.other, endingAt: date(6, 19))])
        #expect(activity(lifted, at: date(6, 20)) == nil)
        let ranOnly = ActivitySignals(workouts: [workout(.running, endingAt: date(6, 19))])
        #expect(activity(ranOnly, at: date(6, 20)) == .gymDay)
        let yesterday = ActivitySignals(workouts: [workout(.other, endingAt: date(5, 19))])
        #expect(activity(yesterday, at: date(6, 20)) == .gymDay)
    }

    @Test func atTheGymAndAfterLeavingIt() {
        var presence = PlacePresence()
        presence.record(.fitness, entered: true, at: date(6, 19))
        #expect(activity(ActivitySignals(presence: presence), at: date(6, 19, 30)) == .gymSession)
        presence.record(.fitness, entered: false, at: date(6, 20))
        #expect(presence.left(.fitness) == date(6, 20))
        #expect(activity(ActivitySignals(presence: presence), at: date(6, 21)) == nil)

        var boxing = PlacePresence()
        boxing.record(.gym, entered: true, at: date(11, 10))
        #expect(activity(ActivitySignals(presence: boxing), at: date(11, 10, 30)) == .boxingAtGym)
        #expect(activity(ActivitySignals(runningSince: date(10, 17)), at: date(10, 17, 10)) == .running)
    }

    @Test func runDayWarmsUpUntilARun() {
        #expect(activity(at: date(10, 16)) == nil)
        #expect(activity(at: date(10, 17)) == .runDay)
        let ran = ActivitySignals(workouts: [workout(.running, endingAt: date(10, 18))])
        #expect(activity(ran, at: date(10, 19)) == nil)
    }

    @Test func daysRoundTripThroughDefaults() throws {
        let suite = "lifehub-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(ActivityDays.stored(in: defaults) == .standard)
        let days = ActivityDays(gymWeekdays: [2], runWeekday: nil, runStartMinute: 0)
        days.store(in: defaults)
        #expect(ActivityDays.stored(in: defaults) == days)
        #expect(ActivityEngine.activity(ActivitySignals(), days: days, now: date(10, 18), calendar: calendar) == nil)
    }

    @Test func oldPresenceWithoutDeparturesStillLoads() throws {
        let json = #"{"arrivals":{"home":"2026-10-04T10:00:00Z"}}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let presence = try decoder.decode(PlacePresence.self, from: Data(json.utf8))
        #expect(presence.since(.home) != nil)
        #expect(presence.departures.isEmpty)
        #expect(presence.left(.home) == nil)
    }
}
