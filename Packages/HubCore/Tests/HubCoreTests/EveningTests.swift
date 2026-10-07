import Foundation
import Testing

@testable import HubCore

@Suite struct EveningTests {
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

    var work: ModeRules {
        var work = ModeRules.standard
        work.eveningUntilMinute = 20 * 60
        return work
    }

    var lateOvertime: NeedRules {
        var rules = NeedRules.standard
        rules.overtimeMinute = 21 * 60
        return rules
    }

    @Test func eveningRunsFromTheEndOfWorkToThePickedTimeOnWorkDays() {
        #expect(work.eveningUntil(at: date(5, 18, 29), calendar: calendar) == nil)
        #expect(work.eveningUntil(at: date(5, 18, 30), calendar: calendar) == date(5, 20))
        #expect(work.eveningUntil(at: date(5, 19, 59), calendar: calendar) == date(5, 20))
        #expect(work.eveningUntil(at: date(5, 20), calendar: calendar) == nil)
        #expect(work.eveningUntil(at: date(4, 19), calendar: calendar) == nil)
        #expect(ModeRules.standard.eveningUntil(at: date(5, 19), calendar: calendar) == nil)
        #expect(work.isEvening(date(5, 21), calendar: calendar))
        #expect(!work.isEvening(date(4, 21), calendar: calendar))
    }

    @Test func theEveningIsOvertimeAtTheOffice() {
        func moment(_ now: Date, work: ModeRules) -> CompanionMoment? {
            MomentEngine.office(
                mode: .work,
                since: date(5, 9),
                now: now,
                work: work,
                rules: lateOvertime,
                calendar: calendar
            )
        }
        #expect(moment(date(5, 18, 20), work: work) == .packingUp)
        #expect(moment(date(5, 18, 30), work: work) == .overtime)
        #expect(moment(date(5, 18, 30), work: .standard) == .packingUp)
        #expect(moment(date(5, 20), work: work) == nil)
        let times = MomentEngine.officeTimes(since: date(5, 9), now: date(5, 12), work: work, calendar: calendar)
        #expect(times.contains(date(5, 18, 30)) && times.contains(date(5, 20)))
    }

    @Test func eveningStartsAsTheDefaultHourWhenTurnedOn() {
        #expect(ModeRules.eveningDefaultMinute == 19 * 60)
    }

    @Test func oldRulesDecodeWithTheEveningOff() throws {
        let data = try JSONEncoder().encode(ModeRules.standard)
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "eveningUntilMinute")
        let old = try JSONSerialization.data(withJSONObject: json)
        #expect(try JSONDecoder().decode(ModeRules.self, from: old).eveningUntilMinute == nil)
        let saved = try JSONDecoder().decode(ModeRules.self, from: JSONEncoder().encode(work))
        #expect(saved.eveningUntilMinute == 20 * 60)
    }

    @Test func kuroSaysFinallyOnlyWhenSheLeavesInTheEvening() {
        func log(leftAt: Date) -> ModeLog {
            ModeLog(changes: [
                ModeChange(mode: .work, source: .location, at: date(5, 9), deviceID: "t"),
                ModeChange(mode: .chill, source: .location, at: leftAt, deviceID: "t"),
            ])
        }
        let late = WidgetSnapshot(log: log(leftAt: date(5, 18, 40)), now: date(5, 18, 41), calendar: calendar)
        #expect(late.offWorkLine(at: date(5, 18, 50), persona: .kuro, work: work, calendar: calendar) == "……终于。")
        #expect(late.offWorkLine(at: date(5, 18, 50), persona: .kuro, calendar: calendar) == KuroLines.offWorkLine)
        #expect(late.offWorkLine(at: date(5, 18, 50), work: work, calendar: calendar) == HakuLines.offWorkLine)
        let early = WidgetSnapshot(log: log(leftAt: date(5, 18, 10)), now: date(5, 18, 11), calendar: calendar)
        #expect(early.offWorkLine(at: date(5, 18, 20), persona: .kuro, work: work, calendar: calendar) == "……お疲れ。")
    }
}
