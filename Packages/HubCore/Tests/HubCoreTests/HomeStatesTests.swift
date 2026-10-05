import Foundation
import Testing

@testable import HubCore

@Suite struct HomeStatesTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    // 2026-10-05 is a Monday, 2026-10-04 a Sunday.
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    func home(
        since: Date,
        worked: TimeInterval = 0,
        manualAt: Date? = nil,
        mode: Mode? = .chill,
        at now: Date
    ) -> CompanionMoment? {
        let signals = HomeSignals(since: since, workedToday: worked, manualAt: manualAt)
        return MomentEngine.home(mode: mode, signals: signals, now: now, calendar: calendar)
    }

    func log(_ changes: (Mode, String?, Date)...) -> ModeLog {
        ModeLog(changes: changes.map { ModeChange(mode: $0.0, source: .location, tag: $0.1, at: $0.2, deviceID: "t") })
    }

    @Test func weekdayMorningAtHomeGetsReadyThenWaitsAtTheDoor() {
        let night = date(4, 22)
        #expect(home(since: night, at: date(5, 7, 30)) == .morning)
        #expect(home(since: night, at: date(5, 9, 29)) == .morning)
        #expect(home(since: night, at: date(5, 9, 30)) == .timeToLeave)
        #expect(home(since: night, at: date(5, 10, 59)) == .timeToLeave)
        // HAKU gives up after 90 minutes, so a sick day at home isn't nagged.
        #expect(home(since: night, at: date(5, 11)) == nil)
        #expect(home(since: night, mode: nil, at: date(5, 10)) == .timeToLeave)
        // Not on a Sunday, and before 05:00 still belongs to the night before.
        #expect(home(since: date(3, 22), at: date(4, 10)) == nil)
        #expect(home(since: night, at: date(5, 3)) == .blanket)
    }

    @Test func noMorningNudgeOnADayOffOrInAnotherMode() {
        let night = date(4, 22)
        // A manual change since 05:00 means Mike decided the day himself.
        #expect(home(since: night, manualAt: date(5, 8), at: date(5, 10)) == nil)
        #expect(home(since: night, manualAt: date(4, 21), at: date(5, 10)) == .timeToLeave)
        #expect(home(since: night, mode: .work, at: date(5, 10)) == nil)
        #expect(home(since: night, mode: .money, at: date(5, 8)) == nil)
    }

    @Test func hakuGivesUpWaitingOnceTheWaitEnds() {
        func event(since: Date, manualAt: Date? = nil, mode: Mode? = .chill, at now: Date) -> CompanionEvent? {
            let signals = HomeSignals(since: since, workedToday: 0, manualAt: manualAt)
            return MomentEngine.stayHome(mode: mode, signals: signals, now: now, calendar: calendar)
        }
        let night = date(4, 22)
        #expect(event(since: night, at: date(5, 10, 59)) == nil)
        #expect(event(since: night, at: date(5, 11)) == .stayHome(id: "2026-10-05"))
        #expect(event(since: night, at: date(5, 15)) == .stayHome(id: "2026-10-05"))
        // Not after work hours, on a day off, in another mode, or when Mike only got home later.
        #expect(event(since: night, at: date(5, 18, 30)) == nil)
        #expect(event(since: night, manualAt: date(5, 8), at: date(5, 12)) == nil)
        #expect(event(since: night, mode: .work, at: date(5, 12)) == nil)
        #expect(event(since: date(5, 11, 30), at: date(5, 12)) == nil)
        #expect(event(since: date(3, 22), at: date(4, 12)) == nil)
    }

    @Test func aLongWorkDayComesHomeCollapsed() {
        let arrived = date(5, 19)
        let long = MomentEngine.longWorkDay
        #expect(home(since: arrived, worked: long, at: date(5, 19, 10)) == .collapsed)
        #expect(home(since: arrived, worked: long, at: date(5, 19, 30)) == nil)
        #expect(home(since: arrived, worked: long - 60, at: date(5, 19, 10)) == nil)
    }

    @Test func aQuietEveningIsTheBlanket() {
        let arrived = date(4, 18)
        #expect(home(since: arrived, at: date(4, 20, 59)) == nil)
        #expect(home(since: arrived, at: date(4, 21)) == .blanket)
        #expect(home(since: arrived, at: date(5, 0, 30)) == .blanket)
    }

    @Test func homeStatesGiveWayToEverythingElse() {
        let signals = HomeSignals(since: date(4, 22), workedToday: 0, manualAt: nil)
        func moment(
            activity: CompanionActivity? = nil,
            need: CompanionNeed? = nil,
            home: HomeSignals?
        ) -> CompanionMoment? {
            MomentEngine.moment(
                mode: .chill,
                sideHustle: nil,
                activity: activity,
                need: need,
                departing: false,
                officeSince: nil,
                home: home,
                now: date(5, 10),
                calendar: calendar
            )
        }
        #expect(moment(home: signals) == .timeToLeave)
        #expect(moment(home: nil) == nil)
        #expect(moment(need: .couchScroll, home: signals) == nil)
        #expect(moment(activity: .running, home: signals) == nil)
    }

    @Test func workedTodayCountsFromFiveInTheMorning() {
        let day = log((.work, nil, date(4, 20)), (.chill, nil, date(5, 6)), (.work, nil, date(5, 9)))
        #expect(MomentEngine.workedToday(day, now: date(5, 17), calendar: calendar) == 9 * 60 * 60)
    }

    @Test func tracesComeFromWhatHappenedToday() {
        let now = date(5, 22)
        func traces(
            _ log: ModeLog,
            workouts: [WorkoutSummary] = [],
            energy: EnergyLevel? = nil
        ) -> Set<CompanionTrace> {
            MomentEngine.traces(log: log, workouts: workouts, energy: energy, now: now, calendar: calendar)
        }
        #expect(traces(ModeLog()).isEmpty)
        let coding = log((.money, "vibeCoding", date(5, 20)), (.chill, nil, date(5, 20, 29)))
        #expect(traces(coding).isEmpty)
        let longer = log((.money, "vibeCoding", date(5, 20)), (.chill, nil, date(5, 20, 30)))
        #expect(traces(longer) == [.pcGlow])
        let shooting = log((.money, "shooting", date(5, 20)), (.chill, nil, date(5, 21)))
        #expect(traces(shooting).isEmpty)
        let gym = log((.boxing, nil, date(5, 19)), (.chill, nil, date(5, 20)))
        #expect(traces(gym) == [.bandage])
        let bag = WorkoutSummary(id: "w", kind: .boxing, start: date(5, 7), end: date(5, 7, 40))
        #expect(traces(ModeLog(), workouts: [bag], energy: .full) == [.bandage, .sunlight])
        // Yesterday's boxing has faded by today's 05:00.
        let yesterday = WorkoutSummary(id: "y", kind: .boxing, start: date(4, 10), end: date(4, 11))
        #expect(traces(ModeLog(), workouts: [yesterday], energy: .okay).isEmpty)
    }

    @Test func lastingTracesBuildUpAndStay() {
        func earned(_ win: Win, _ times: Int) -> [CanEntry] {
            (0..<times).map { CanEntry.earned(win, source: "\(win)\($0)", at: date(1, 12), deviceID: "t") }
        }
        let few = CanLedger(entries: earned(.boxing, 4) + earned(.run5k, 1))
        #expect(MomentEngine.lastingTraces(log: ModeLog(), ledger: few, now: date(5, 12)).isEmpty)
        let enough = CanLedger(entries: earned(.boxing, 5) + earned(.run5k, 2))
        let lasting = MomentEngine.lastingTraces(log: ModeLog(), ledger: enough, now: date(5, 12))
        #expect(lasting == [.wornGloves, .runningShoes])
        let coding = log(
            (.money, "vibeCoding", date(1, 10)),
            (.chill, nil, date(1, 16)),
            (.money, "vibeCoding", date(2, 10))
        )
        #expect(MomentEngine.lastingTraces(log: coding, ledger: CanLedger(), now: date(2, 13, 59)).isEmpty)
        #expect(MomentEngine.lastingTraces(log: coding, ledger: CanLedger(), now: date(2, 14)) == [.deskMonitor])
    }

    @Test func snapshotCarriesTodaysTracesAndHomeSignals() {
        var snapshot = WidgetSnapshot(mode: .chill, since: nil, updatedAt: date(5, 20))
        snapshot.traces = [.bandage]
        snapshot.workedToday = 9 * 60 * 60
        snapshot.manualAt = date(5, 8)
        #expect(snapshot.traces(at: date(5, 23), calendar: calendar) == [.bandage])
        #expect(snapshot.traces(at: date(6, 6), calendar: calendar).isEmpty)
        snapshot.lasting = [.wornGloves]
        #expect(snapshot.traces(at: date(5, 23), calendar: calendar) == [.bandage, .wornGloves])
        #expect(snapshot.traces(at: date(6, 6), calendar: calendar) == [.wornGloves])
        let home = snapshot.home(since: date(5, 19), at: date(5, 19, 10), calendar: calendar)
        #expect(home == HomeSignals(since: date(5, 19), workedToday: 9 * 60 * 60, manualAt: date(5, 8)))
        #expect(snapshot.home(since: date(5, 19), at: date(6, 6), calendar: calendar)?.workedToday == 0)
        #expect(snapshot.home(since: nil, at: date(5, 21), calendar: calendar) == nil)
        let tap = ModeChange(mode: .money, at: date(5, 21), deviceID: "widget")
        #expect(snapshot.applying(.mode(tap)).manualAt == date(5, 21))
    }

    @Test func homeStatesHaveLockScreenLines() {
        for moment in [CompanionMoment.collapsed, .blanket, .morning, .timeToLeave] {
            #expect(HakuLines.scene(for: moment) != nil, "\(moment)")
        }
        #expect(HakuLines.library[.comeHome]?.first == "你也活着回来了啊。")
    }
}
