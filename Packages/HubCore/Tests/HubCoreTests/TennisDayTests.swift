import Foundation
import Testing

@testable import HubCore

@Suite struct TennisDayTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    func sessions(_ dates: [Date]) -> CanLedger {
        CanLedger(entries: dates.map { CanEntry.earned(.boxing, source: "\($0)", at: $0, deviceID: "t") })
    }

    func rules(_ ledger: CanLedger, persona: Persona = .kuro) -> NeedRules {
        NeedRules.standard(for: persona, ledger: ledger, now: date(31, 12), calendar: calendar)
    }

    @Test func hakuKeepsTheStandardRules() {
        #expect(rules(sessions([date(17, 10), date(24, 10)]), persona: .haku) == .standard)
    }

    @Test func kuroPlaysOnSaturdayUntilADayIsLearned() {
        let rules = rules(CanLedger())
        #expect(rules.persona == .kuro)
        #expect(rules.boxingWeekday == NeedRules.tennisWeekday)
        // One week is not enough.
        #expect(self.rules(sessions([date(25, 10)])).boxingWeekday == NeedRules.tennisWeekday)
    }

    @Test func kuroLearnsTheDaySheGoes() {
        // Sundays 18th and 25th.
        #expect(rules(sessions([date(18, 10), date(25, 10)])).boxingWeekday == 1)
        // Wednesdays in three weeks beat Sundays in two.
        let both = sessions([date(7, 18), date(14, 18), date(21, 18), date(18, 10), date(25, 10)])
        #expect(rules(both).boxingWeekday == 4)
        // A tie goes to the earlier weekday: Sunday before Friday.
        let tie = sessions([date(16, 18), date(23, 18), date(18, 10), date(25, 10)])
        #expect(rules(tie).boxingWeekday == 1)
    }

    @Test func kuroHasHerOwnTennisLines() {
        let kuro = rules(CanLedger())
        // Saturday 31st, 10:00, inside the warm-up window.
        let reading = NeedEngine.need(NeedSignals(), now: date(31, 10), rules: kuro, calendar: calendar)
        #expect(reading?.need == .boxingWarmup)
        #expect(reading?.reasons == ["今天网球。……拍子带好了。"])
        #expect(NeedEngine.inviteText(for: .boxingWarmup, persona: .kuro) == "……走吗。网球包拎好了。")
        #expect(NeedEngine.inviteText(for: .boxingWarmup) == "拳套戴好了，出发去拳馆？")
        let next = NeedEngine.nextScheduled(after: date(30, 12), rules: kuro, calendar: calendar)
        #expect(next?.from == date(31, 9))
        #expect(next?.line == "今天网球。……拍子带好了。")
    }
}
