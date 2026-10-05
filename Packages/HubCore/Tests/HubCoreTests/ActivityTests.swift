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

        let lifted = ActivitySignals(workouts: [workout(.other, endingAt: date(6, 19))], calendar: calendar)
        #expect(activity(lifted, at: date(6, 20)) == nil)
        let ranOnly = ActivitySignals(workouts: [workout(.running, endingAt: date(6, 19))], calendar: calendar)
        #expect(activity(ranOnly, at: date(6, 20)) == .gymDay)
        let yesterday = ActivitySignals(workouts: [workout(.other, endingAt: date(5, 19))], calendar: calendar)
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
        let ran = ActivitySignals(workouts: [workout(.running, endingAt: date(10, 18))], calendar: calendar)
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

    @Test func widgetsRedrawWhenGymOrRunDayStarts() {
        let work = ModeRules.standard.workEndMinute
        let tuesday = ActivityEngine.startTimes(on: date(6, 12), calendar: calendar)
        #expect(tuesday == [date(6, work / 60, work % 60)])
        #expect(ActivityEngine.startTimes(on: date(10, 9), calendar: calendar) == [date(10, 17)])
        #expect(ActivityEngine.startTimes(on: date(9, 12), calendar: calendar).isEmpty)
        // Before 05:00 it is still the previous hub day.
        #expect(ActivityEngine.startTimes(on: date(7, 2), calendar: calendar) == tuesday)
    }

    @Test func gymVisitEarnsAfterHalfAnHour() {
        #expect(Win.visit(.fitness, from: date(6, 19), to: date(6, 19, 29), calendar: calendar) == nil)
        let visit = Win.visit(.fitness, from: date(6, 19), to: date(6, 19, 30), calendar: calendar)
        #expect(visit?.win == .gym)
        #expect(visit?.at == date(6, 19, 30))
        let lifted = WorkoutSummary(id: "w", kind: .strength, start: date(6, 19, 5), end: date(6, 19, 50))
        #expect(visit?.source == Win.wins(in: [lifted], calendar: calendar).first?.source)
    }

    @Test func boxingGymVisitEarnsBoxingOncePerWeekWithTheWorkout() {
        #expect(Win.visit(.boxing, from: date(11, 10), to: date(11, 10, 29), calendar: calendar) == nil)
        let visit = Win.visit(.boxing, from: date(11, 10), to: date(11, 11), calendar: calendar)
        #expect(visit?.win == .boxing)
        let boxed = WorkoutSummary(id: "b", kind: .boxing, start: date(11, 10, 5), end: date(11, 10, 50))
        #expect(visit?.source == Win.wins(in: [boxed], calendar: calendar).first?.source)
        #expect(Win.visit(.work, from: date(6, 9), to: date(6, 18), calendar: calendar) == nil)
    }
    func gymWins(_ dates: [Date]) -> CanLedger {
        CanLedger(entries: dates.map { CanEntry.earned(.gym, source: "\($0)", at: $0, deviceID: "t") })
    }

    @Test func gymDaysStayUntilThereIsAGymWin() {
        let now = date(31, 12)
        #expect(ActivityDays.standard.learningGym(from: CanLedger(), now: now, calendar: calendar) == .standard)
        // A win older than 4 weeks doesn't count either.
        let old = gymWins([date(1, 20)])
        #expect(ActivityDays.standard.learningGym(from: old, now: now, calendar: calendar) == .standard)
    }

    @Test func gymDaysAreWeekdaysWonInTwoOfFourWeeks() {
        // Tuesdays 13th and 20th, one Thursday on the 22nd, Saturday 31st before 05:00 is Friday the 30th.
        let ledger = gymWins([date(13, 20), date(20, 20), date(22, 20), date(31, 1)])
        let days = ActivityDays.standard.learningGym(from: ledger, now: date(31, 12), calendar: calendar)
        #expect(days.gymWeekdays == [3])
        #expect(days.runWeekday == ActivityDays.standard.runWeekday)
    }

    @Test func twoWinsInOneWeekCountOnceAndKeepTheStoredDays() {
        let ledger = gymWins([date(27, 20), date(27, 21)])
        let days = ActivityDays.standard.learningGym(from: ledger, now: date(31, 12), calendar: calendar)
        #expect(days == .standard)
    }
}
