import Foundation
import Testing

@testable import HubCore

@Suite struct ModeEngineTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    // 2026-10-05 is a Monday, 2026-10-03 a Saturday.
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    func log(_ changes: (Mode, ModeChange.Source, Date)...) -> ModeLog {
        ModeLog(changes: changes.map { ModeChange(mode: $0.0, source: $0.1, at: $0.2, deviceID: "test") })
    }

    func decide(_ trigger: ModeTrigger, _ log: ModeLog, at now: Date) -> ModeDecision? {
        ModeEngine.decide(trigger, log: log, now: now, calendar: calendar)
    }

    @Test func scheduleFollowsWorkdayHours() {
        let rules = ModeRules.standard
        #expect(ModeEngine.scheduledMode(at: date(5, 9, 29), rules: rules, calendar: calendar) == .chill)
        #expect(ModeEngine.scheduledMode(at: date(5, 9, 30), rules: rules, calendar: calendar) == .work)
        #expect(ModeEngine.scheduledMode(at: date(5, 18, 29), rules: rules, calendar: calendar) == .work)
        #expect(ModeEngine.scheduledMode(at: date(5, 18, 30), rules: rules, calendar: calendar) == .chill)
        #expect(ModeEngine.scheduledMode(at: date(3, 12), rules: rules, calendar: calendar) == .chill)
    }

    @Test func lastScheduleChangeSkipsTheWeekend() {
        let rules = ModeRules.standard
        #expect(ModeEngine.lastScheduleChange(before: date(5, 12), rules: rules, calendar: calendar) == date(5, 9, 30))
        #expect(ModeEngine.lastScheduleChange(before: date(5, 8), rules: rules, calendar: calendar) == date(2, 18, 30))
        let none = ModeRules(workdays: [], workStartMinute: 0, workEndMinute: 0, manualHold: 0, gymMinimumStay: 0)
        #expect(ModeEngine.lastScheduleChange(before: date(5, 8), rules: none, calendar: calendar) == nil)
    }

    @Test func scheduleSwitchesAnEmptyLog() {
        let decision = decide(.schedule, ModeLog(), at: date(5, 10))
        #expect(decision == ModeDecision(mode: .work, source: .schedule, reason: "工作日上班时间"))
    }

    @Test func scheduleActsOncePerPeriod() {
        // Work started at 9:30; Mike picked money at 10:00, more than 2 h ago.
        let picked = log((.work, .schedule, date(5, 9, 30)), (.money, .manual, date(5, 10)))
        #expect(decide(.schedule, picked, at: date(5, 13)) == nil)
        #expect(decide(.schedule, picked, at: date(5, 18, 31))?.mode == .chill)
        #expect(decide(.schedule, picked, at: date(5, 18, 31))?.reason == "下班时间")
    }

    @Test func scheduleWaitsTwoHoursAfterAManualChange() {
        let manual = log((.money, .manual, date(5, 17, 45)))
        #expect(decide(.schedule, manual, at: date(5, 19, 44)) == nil)
        #expect(decide(.schedule, manual, at: date(5, 19, 45))?.mode == .chill)
    }

    @Test func scheduleLeavesTheMatchingModeAlone() {
        #expect(decide(.schedule, log((.chill, .inferred, date(4, 20))), at: date(5, 8)) == nil)
    }

    @Test func scheduleDoesNotEndAGymVisit() {
        let gym = log((.work, .schedule, date(5, 9, 30)), (.boxing, .location, date(5, 18)))
        #expect(decide(.schedule, gym, at: date(5, 19)) == nil)
    }

    @Test func gymWinsEvenRightAfterAManualChange() {
        let manual = log((.chill, .manual, date(5, 18, 50)))
        let decision = decide(.enteredGym, manual, at: date(5, 19))
        #expect(decision == ModeDecision(mode: .boxing, source: .location, reason: "到拳馆了"))
        #expect(decide(.enteredGym, log((.boxing, .manual, date(5, 18))), at: date(5, 19)) == nil)
    }

    @Test func leavingTheGymRestoresTheEarlierMode() {
        let visit = log((.chill, .manual, date(5, 18, 40)), (.boxing, .location, date(5, 19)))
        #expect(decide(.leftGym, visit, at: date(5, 19, 29)) == nil)
        let decision = decide(.leftGym, visit, at: date(5, 20, 30))
        #expect(decision == ModeDecision(mode: .chill, source: .location, reason: "离开拳馆，回到「下班 Chill」"))
    }

    @Test func leavingTheGymAfterWorkHoursFollowsTheSchedule() {
        let visit = log((.work, .schedule, date(5, 9, 30)), (.boxing, .location, date(5, 18)))
        let decision = decide(.leftGym, visit, at: date(5, 20))
        #expect(decision?.mode == .chill)
        let left = log(
            (.work, .schedule, date(5, 9, 30)),
            (.boxing, .location, date(5, 18)),
            (.chill, .location, date(5, 20))
        )
        #expect(decide(.schedule, left, at: date(5, 21)) == nil)
    }

    @Test func leavingTheGymWithNoHistoryUsesTheSchedule() {
        let visit = log((.boxing, .location, date(5, 7)))
        #expect(decide(.leftGym, visit, at: date(5, 10))?.mode == .work)
    }

    @Test func leavingTheGymKeepsAManualChangeMadeThere() {
        let changed = log(
            (.chill, .manual, date(5, 18)),
            (.boxing, .location, date(5, 19)),
            (.money, .manual, date(5, 20))
        )
        #expect(decide(.leftGym, changed, at: date(5, 21)) == nil)
        let boxedByHand = log((.boxing, .manual, date(5, 18)), (.boxing, .location, date(5, 19)))
        #expect(decide(.leftGym, boxedByHand, at: date(5, 21)) == nil)
    }

    @Test func officeSwitchesToWorkUnlessHeld() {
        #expect(decide(.enteredOffice, log((.chill, .schedule, date(5, 8))), at: date(5, 9))?.mode == .work)
        #expect(decide(.enteredOffice, log((.money, .manual, date(5, 8))), at: date(5, 9)) == nil)
        #expect(decide(.enteredOffice, log((.work, .schedule, date(5, 9, 30))), at: date(5, 9, 40)) == nil)
    }

    @MainActor @Test func storeAppliesTheDecision() {
        let store = ModeStore(fileURL: nil, deviceID: "test")
        let decision = store.autoSwitch(.schedule, now: date(5, 10), calendar: calendar)
        #expect(decision?.mode == .work)
        #expect(store.log.current?.source == .schedule)
        #expect(store.autoSwitch(.schedule, now: date(5, 11), calendar: calendar) == nil)
    }
}
