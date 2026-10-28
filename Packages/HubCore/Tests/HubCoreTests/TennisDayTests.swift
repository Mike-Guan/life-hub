import Foundation
import Testing

@testable import HubCore

// An identity day learned on Sunday with class at 10:00, for tests of the warm-up itself.
extension NeedRules {
    static let sundayFixture: NeedRules = {
        var rules = NeedRules.standard
        rules.boxingWeekday = 1
        return rules
    }()
}

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

    @Test func noIdentityDayUntilOneIsLearned() {
        let none = rules(CanLedger())
        #expect(none.persona == .kuro)
        #expect(none.boxingWeekday == nil)
        // One week is not enough.
        #expect(rules(sessions([date(25, 10)])).boxingWeekday == nil)
        // A swimmer who never boxed gets no boxing warm-up on Sunday morning.
        let haku = rules(CanLedger(), persona: .haku)
        #expect(NeedEngine.need(NeedSignals(), now: date(25, 9), rules: haku, calendar: calendar) == nil)
        #expect(NeedEngine.nextScheduled(after: date(24, 12), rules: haku, calendar: calendar) == nil)
    }

    @Test func oldBoxingRecordsLearnSundayAroundTheUsualArrival() {
        // Sundays 18th and 25th, leaving the gym at 11:40: arrival taken as 10:10, rounded to 10:00.
        let ledger = sessions([date(18, 11, 40), date(25, 11, 40)])
        let haku = rules(ledger, persona: .haku)
        #expect(haku.boxingWeekday == 1)
        #expect(haku.boxingStartMinute == 10 * 60)
        #expect(haku.boxingWarmupStartMinute == 9 * 60)
        #expect(haku.boxingWarmupEndMinute == 12 * 60)
        #expect(haku.boxingFirstUntilMinute == 10 * 60 + 30)
        // Arrivals on that weekday win over the estimate; others are ignored.
        let arrivals = [date(18, 9, 50), date(25, 9, 40), date(24, 18)]
        let arrived = NeedRules.standard(
            for: .haku,
            ledger: ledger,
            arrivals: arrivals,
            now: date(31, 12),
            calendar: calendar
        )
        #expect(arrived.boxingStartMinute == 9 * 60 + 45)
        #expect(arrived.boxingWarmupStartMinute == 8 * 60 + 45)
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
        // Saturdays 17th and 24th, leaving at 11:30: warm-up from 9:00 on Saturday 31st.
        let kuro = rules(sessions([date(17, 11, 30), date(24, 11, 30)]))
        let reading = NeedEngine.need(NeedSignals(), now: date(31, 10), rules: kuro, calendar: calendar)
        #expect(reading?.need == .boxingWarmup)
        #expect(reading?.reasons == ["今天网球。……拍子带好了。"])
        #expect(NeedEngine.inviteText(for: .boxingWarmup, persona: .kuro) == "……走吗。网球包拎好了。")
        #expect(NeedEngine.inviteText(for: .boxingWarmup) == "拳套戴好了，出发去拳馆？")
        let next = NeedEngine.nextScheduled(after: date(30, 12), rules: kuro, calendar: calendar)
        #expect(next?.from == date(31, 9))
        #expect(next?.line == "今天网球。……拍子带好了。")
    }

    @Test func theIdentityDayFollowsTheUsersCard() {
        let ledger = sessions([date(18, 11, 40), date(25, 11, 40)])
        // No card, no identity day, even with old boxing records.
        let none = NeedRules.standard(
            for: .haku,
            ledger: ledger,
            cards: ModeCards(),
            now: date(31, 12),
            calendar: calendar
        )
        #expect(none.identity == nil)
        #expect(none.boxingWeekday == nil)
        // HAKU with the tennis card warms up for tennis.
        let tennis = NeedRules.standard(
            for: .haku,
            ledger: ledger,
            cards: ModeCards(identity: .tennis),
            now: date(31, 12),
            calendar: calendar
        )
        #expect(tennis.identity == .tennis)
        let reading = NeedEngine.need(NeedSignals(), now: date(25, 10), rules: tennis, calendar: calendar)
        #expect(reading?.reasons == ["球拍在门口。去不去随你。"])
        #expect(NeedEngine.inviteText(for: .boxingWarmup, persona: .haku, identity: .tennis) == "球拍在门口。去不去随你。")
        // The character's own card keeps its own lines.
        #expect(NeedEngine.inviteText(for: .boxingWarmup, persona: .haku, identity: .boxing) == "拳套戴好了，出发去拳馆？")
        #expect(NeedEngine.inviteText(for: .boxingWarmup, persona: .kuro, identity: .tennis) == "……走吗。网球包拎好了。")
    }
}
