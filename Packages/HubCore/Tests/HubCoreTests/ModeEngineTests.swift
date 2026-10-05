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

    @Test func theClockNeverSwitchesTheMode() {
        // Mike, 2026-10-05: at 10:00 on a work day, still at home, the mode stays as it was.
        let morning = log((.chill, .manual, date(4, 23)))
        for trigger in [ModeTrigger.leftOffice, .leftGym] {
            #expect(decide(trigger, morning, at: date(5, 10)) == nil)
        }
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

    @Test func leavingTheGymAfterAnAutomaticModeGoesToChill() {
        let visit = log((.work, .location, date(5, 9, 30)), (.boxing, .location, date(5, 18)))
        #expect(decide(.leftGym, visit, at: date(5, 20))?.mode == .chill)
        #expect(decide(.leftGym, log((.boxing, .location, date(5, 7))), at: date(5, 10))?.mode == .chill)
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

    @Test func walkingPastAPlaceTakesBackItsSwitch() {
        let passBy = ModeTrigger.passedBy(arrivedAt: date(5, 19))
        let passed = log((.money, .manual, date(5, 18)), (.boxing, .location, date(5, 19)))
        let back = ModeDecision(mode: .money, source: .location, reason: "只是路过")
        #expect(decide(passBy, passed, at: date(5, 19, 2)) == back)
        #expect(decide(passBy, passed, at: date(5, 19, 3)) == nil)
        #expect(decide(passBy, log((.boxing, .location, date(5, 19))), at: date(5, 19, 1))?.mode == .chill)
        let changedThere = log((.boxing, .location, date(5, 19)), (.work, .manual, date(5, 19, 1)))
        #expect(decide(passBy, changedThere, at: date(5, 19, 2)) == nil)
        #expect(decide(passBy, log((.chill, .manual, date(5, 18))), at: date(5, 19, 1)) == nil)
    }

    @Test func officeSwitchesToWorkUnlessHeld() {
        #expect(decide(.enteredOffice, log((.chill, .schedule, date(5, 8))), at: date(5, 9))?.mode == .work)
        #expect(decide(.enteredOffice, log((.money, .manual, date(5, 8))), at: date(5, 9)) == nil)
        #expect(decide(.enteredOffice, log((.work, .schedule, date(5, 9, 30))), at: date(5, 9, 40)) == nil)
    }

    @Test func leavingTheOfficeEndsWorkUnlessHeld() {
        let decision = decide(.leftOffice, log((.work, .location, date(5, 9))), at: date(5, 18, 40))
        #expect(decision == ModeDecision(mode: .chill, source: .location, reason: "离开公司了"))
        #expect(decide(.leftOffice, log((.work, .manual, date(5, 18))), at: date(5, 18, 40)) == nil)
        #expect(decide(.leftOffice, log((.money, .manual, date(5, 9))), at: date(5, 18, 40)) == nil)
    }

    @Test func leavingTheOfficeBefore1730KeepsWork() {
        let day = log((.work, .location, date(5, 9)))
        #expect(decide(.leftOffice, day, at: date(5, 12, 30)) == nil)
        #expect(decide(.leftOffice, day, at: date(5, 17, 29)) == nil)
        #expect(decide(.leftOffice, day, at: date(5, 17, 30))?.mode == .chill)
    }

    @Test func addedPlacesSwitchUnlessHeld() {
        let studio = ModeTrigger.enteredPlace(.money, name: "工作室")
        let decision = decide(studio, log((.chill, .schedule, date(3, 14))), at: date(3, 15))
        #expect(decision?.mode == .money)
        #expect(decision?.reason == "到工作室了")
        #expect(decide(studio, log((.chill, .manual, date(3, 14))), at: date(3, 15)) == nil)
        #expect(decide(studio, log((.money, .schedule, date(3, 14))), at: date(3, 15)) == nil)
    }

    @MainActor @Test func storeAppliesTheDecision() {
        let store = ModeStore(fileURL: nil, deviceID: "test")
        let decision = store.autoSwitch(.enteredOffice, now: date(5, 10), calendar: calendar)
        #expect(decision?.mode == .work)
        #expect(store.log.current?.source == .location)
        #expect(store.autoSwitch(.enteredOffice, now: date(5, 11), calendar: calendar) == nil)
    }

    @Test func offWorkNoticeOnlyWhenAtWork() {
        let rules = ModeRules.standard
        let notice = { (now: Date, mode: Mode?, office: Bool) in
            rules.offWorkNotice(on: now, mode: mode, atOffice: office, calendar: self.calendar)
        }
        #expect(notice(date(5, 10), .work, false) == date(5, 18, 15))
        #expect(notice(date(5, 10), .chill, true) == date(5, 18, 15))
        // Not at work, already past, or not a work day: none.
        #expect(notice(date(5, 10), .chill, false) == nil)
        #expect(notice(date(5, 10), nil, false) == nil)
        #expect(notice(date(5, 18, 15), .work, true) == nil)
        #expect(notice(date(4, 10), .work, true) == nil)

        var early = rules
        early.workEndMinute = 10
        #expect(early.offWorkNotice(on: date(5, 0, 5), mode: .work, atOffice: false, calendar: calendar) == nil)
    }

    @Test func rulesRoundTripThroughDefaults() throws {
        let suite = "lifehub-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(ModeRules.stored(in: defaults) == .standard)
        var rules = ModeRules.standard
        rules.workEndMinute = 19 * 60
        rules.store(in: defaults)
        #expect(ModeRules.stored(in: defaults) == rules)
        defaults.set(Data("x".utf8), forKey: "modeRules")
        #expect(ModeRules.stored(in: defaults) == .standard)
    }
}
