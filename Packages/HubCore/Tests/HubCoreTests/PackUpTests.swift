import Foundation
import Testing

@testable import HubCore

@Suite struct PackUpTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    // 2026-10-05 is a Monday, 2026-10-04 a Sunday. Default work hours end at 18:30.
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    func office(at now: Date, mode: Mode? = .work, since: Date? = nil) -> CompanionMoment? {
        let arrived = since ?? calendar.startOfDay(for: now).addingTimeInterval(9 * 60 * 60)
        return MomentEngine.office(mode: mode, since: arrived, now: now, calendar: calendar)
    }

    @Test func packingUpFromFifteenMinutesBeforeTheEnd() {
        #expect(office(at: date(5, 18, 14)) == nil)
        #expect(office(at: date(5, 18, 15)) == .packingUp)
        #expect(office(at: date(5, 18, 59)) == .packingUp)
        // 30 minutes after the end, back to plain work; 19:00 is also overtime.
        #expect(office(at: date(5, 19)) == .overtime)
    }

    @Test func packingUpEndsThirtyMinutesAfterWithLateOvertime() {
        var rules = NeedRules.standard
        rules.overtimeMinute = 20 * 60
        func moment(_ now: Date) -> CompanionMoment? {
            MomentEngine.office(mode: .work, since: date(5, 9), now: now, rules: rules, calendar: calendar)
        }
        #expect(moment(date(5, 18, 59)) == .packingUp)
        #expect(moment(date(5, 19)) == nil)
    }

    @Test func packingUpNeedsWorkModeTheOfficeAndAWorkDay() {
        #expect(office(at: date(5, 18, 20), mode: .chill) == nil)
        #expect(office(at: date(4, 18, 20)) == nil)
        let away = MomentEngine.office(mode: .work, since: nil, now: date(5, 18, 20), calendar: calendar)
        #expect(away == nil)
    }

    @Test func packingUpFollowsTheWorkHours() {
        var work = ModeRules.standard
        work.workEndMinute = 17 * 60 + 30
        let moment = MomentEngine.office(
            mode: .work,
            since: date(5, 9),
            now: date(5, 17, 20),
            work: work,
            calendar: calendar
        )
        #expect(moment == .packingUp)
    }

    @Test func packingUpGivesWayToScrollingAndSitting() {
        func moment(_ need: CompanionNeed?, stiff: Bool = false) -> CompanionMoment? {
            MomentEngine.moment(
                mode: .work,
                sideHustle: nil,
                activity: nil,
                need: need,
                departing: false,
                officeSince: date(5, 9),
                stiff: stiff,
                now: date(5, 18, 20),
                calendar: calendar
            )
        }
        #expect(moment(nil) == .packingUp)
        #expect(moment(.slacking) == .slacking)
        #expect(moment(nil, stiff: true) == .stiff)
        // Packing up is quiet: it has no lines of its own.
        #expect(HakuLines.scene(for: .packingUp) == nil)
    }

    func log(_ changes: [(Mode, ModeChange.Source, Date)]) -> ModeLog {
        ModeLog(changes: changes.map { ModeChange(mode: $0.0, source: $0.1, at: $0.2, deviceID: "t") })
    }

    @Test func leavingTheOfficeSaysItOnce() {
        let left = log([(.work, .location, date(5, 9)), (.chill, .location, date(5, 18, 40))])
        #expect(HakuLines.offWorkUntil(left, now: date(5, 18, 39), calendar: calendar) == nil)
        #expect(HakuLines.offWorkUntil(left, now: date(5, 18, 40), calendar: calendar) == date(5, 19, 10))
        #expect(HakuLines.offWorkUntil(left, now: date(5, 19, 10), calendar: calendar) == nil)
        #expect(HakuLines.offWorkLine == "……收工。")
    }

    @Test func otherChangesToChillSayNothing() {
        let byHand = log([(.work, .location, date(5, 9)), (.chill, .manual, date(5, 18, 40))])
        #expect(HakuLines.offWorkUntil(byHand, now: date(5, 18, 45), calendar: calendar) == nil)
        let passedBy = log([(.work, .location, date(5, 18, 38)), (.chill, .location, date(5, 18, 40))])
        #expect(HakuLines.offWorkUntil(passedBy, now: date(5, 18, 45), calendar: calendar) == nil)
        let fromBoxing = log([(.boxing, .location, date(5, 17)), (.chill, .location, date(5, 18, 40))])
        #expect(HakuLines.offWorkUntil(fromBoxing, now: date(5, 18, 45), calendar: calendar) == nil)
        let early = log([(.work, .manual, date(5, 9)), (.chill, .location, date(5, 17, 20))])
        #expect(HakuLines.offWorkUntil(early, now: date(5, 17, 25), calendar: calendar) == nil)
    }

    @Test func widgetsShowTheOffWorkLineFromTheSnapshot() {
        let left = log([(.work, .location, date(5, 9)), (.chill, .location, date(5, 18, 40))])
        let snapshot = WidgetSnapshot(log: left, now: date(5, 18, 41), calendar: calendar)
        #expect(snapshot.offWorkLine(at: date(5, 18, 50)) == HakuLines.offWorkLine)
        #expect(snapshot.offWorkLine(at: date(5, 18, 50), persona: .kuro) == KuroLines.offWorkLine)
        #expect(snapshot.offWorkLine(at: date(5, 19, 10)) == nil)
        #expect(snapshot.needTimes.contains(date(5, 19, 10)))
    }
}
