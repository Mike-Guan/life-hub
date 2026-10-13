import Foundation
import Testing

@testable import HubCore

// A routine learned from wins, for tests that need gym and run days.
extension ActivityDays {
    /// Gym Tuesday to Thursday, run Saturday from 17:00.
    static let learnedFixture = ActivityDays(gymWeekdays: [3, 4, 5], runWeekday: 7, runStartMinute: 17 * 60)
}

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

    func activity(
        _ signals: ActivitySignals = ActivitySignals(),
        mode: Mode? = .chill,
        days: ActivityDays = .learnedFixture,
        at now: Date
    ) -> CompanionActivity? {
        ActivityEngine.activity(signals, mode: mode, days: days, now: now, calendar: calendar)
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
        // Lifting is for Chill: in another mode at the gym, HAKU just follows the mode.
        #expect(activity(ActivitySignals(presence: presence), mode: .work, at: date(6, 19, 30)) == nil)
        #expect(activity(ActivitySignals(presence: presence), mode: .money, at: date(6, 19, 30)) == nil)
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
        let none = ActivityEngine.activity(
            ActivitySignals(),
            mode: .chill,
            days: days,
            now: date(10, 18),
            calendar: calendar
        )
        #expect(none == nil)
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
        let days = ActivityDays.learnedFixture
        let tuesday = ActivityEngine.startTimes(on: date(6, 12), days: days, calendar: calendar)
        #expect(tuesday == [date(6, work / 60, work % 60)])
        #expect(ActivityEngine.startTimes(on: date(10, 9), days: days, calendar: calendar) == [date(10, 17)])
        #expect(ActivityEngine.startTimes(on: date(9, 12), days: days, calendar: calendar).isEmpty)
        // Before 05:00 it is still the previous hub day.
        #expect(ActivityEngine.startTimes(on: date(7, 2), days: days, calendar: calendar) == tuesday)
        #expect(ActivityEngine.startTimes(on: date(6, 12), calendar: calendar).isEmpty)
    }

    @Test func gymVisitEarnsAfterHalfAnHour() {
        #expect(Win.visit(.fitness, from: date(6, 19), to: date(6, 19, 29), identity: nil, calendar: calendar) == nil)
        let visit = Win.visit(.fitness, from: date(6, 19), to: date(6, 19, 30), identity: nil, calendar: calendar)
        #expect(visit?.win == .gym)
        #expect(visit?.at == date(6, 19, 30))
        let lifted = WorkoutSummary(id: "w", kind: .strength, start: date(6, 19, 5), end: date(6, 19, 50))
        #expect(visit?.source == Win.wins(in: [lifted], identity: .boxing, calendar: calendar).first?.source)
    }

    @Test func boxingGymVisitEarnsBoxingOncePerWeekWithTheWorkout() {
        let arrived = date(11, 10)
        #expect(Win.visit(.boxing, from: arrived, to: date(11, 10, 29), identity: .boxing, calendar: calendar) == nil)
        let visit = Win.visit(.boxing, from: arrived, to: date(11, 11), identity: .boxing, calendar: calendar)
        #expect(visit?.win == .boxing)
        let boxed = WorkoutSummary(id: "b", kind: .boxing, start: date(11, 10, 5), end: date(11, 10, 50))
        #expect(visit?.source == Win.wins(in: [boxed], identity: .boxing, calendar: calendar).first?.source)
        #expect(Win.visit(.work, from: date(6, 9), to: date(6, 18), identity: .boxing, calendar: calendar) == nil)
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

    @Test func aNewUserHasNoGymDayOrRunDay() {
        #expect(activity(days: .standard, at: date(6, 18, 30)) == nil)
        #expect(activity(days: .standard, at: date(10, 17)) == nil)
    }

    @Test func twoMondaysAtTheGymMakeTheThirdAGymDay() {
        // Mondays 5th and 12th; the 19th is the third Monday.
        let ledger = gymWins([date(5, 20), date(12, 20)])
        let days = ActivityDays.standard.learning(from: ledger, now: date(19, 12), calendar: calendar)
        #expect(days.gymWeekdays == [2])
        #expect(activity(days: days, at: date(19, 18, 30)) == .gymDay)
        let one = gymWins([date(5, 20)])
        let oneMonday = ActivityDays.standard.learning(from: one, now: date(12, 12), calendar: calendar)
        #expect(activity(days: oneMonday, at: date(12, 18, 30)) == nil)
    }

    @Test func theRunDayIsLearnedFromRunsWithTheWarmUpAnHourBeforeTheyEnd() {
        // 5 km runs ending Saturday 17th 18:10 and 24th 18:40, one Friday run; now is Saturday the 31st.
        let runs = [date(17, 18, 10), date(24, 18, 40), date(23, 7)]
        let ledger = CanLedger(entries: runs.map { CanEntry.earned(.run5k, source: "\($0)", at: $0, deviceID: "t") })
        let days = ActivityDays.standard.learning(from: ledger, now: date(31, 12), calendar: calendar)
        #expect(days.runWeekday == 7)
        #expect(days.runStartMinute == 17 * 60 + 30)
        #expect(days.gymWeekdays.isEmpty)
        #expect(activity(days: days, at: date(31, 17, 15)) == nil)
        #expect(activity(days: days, at: date(31, 17, 30)) == .runDay)
        let none = ActivityDays.standard.learningRun(from: CanLedger(), now: date(31, 12), calendar: calendar)
        #expect(none == .standard)
    }

    @Test func twoWinsInOneWeekCountOnceAndKeepTheStoredDays() {
        let ledger = gymWins([date(27, 20), date(27, 21)])
        let days = ActivityDays.standard.learningGym(from: ledger, now: date(31, 12), calendar: calendar)
        #expect(days == .standard)
    }
}
