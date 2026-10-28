import Foundation
import Testing

@testable import HubCore

@Suite struct IrregularWorkTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    // 2026-10-05 is a Monday.
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    var irregular: ModeRules {
        var rules = ModeRules.standard
        rules.workdays = []
        return rules
    }

    let lateBedtime = BedtimeSchedule(startMinute: 60, endMinute: 8 * 60)

    @Test func theEveningFollowsTheBedtime() {
        #expect(irregular.isIrregular)
        #expect(!ModeRules.standard.isIrregular)
        #expect(ModeRules.standard.dayEndMinute(bedtime: lateBedtime) == 18 * 60 + 30)
        // Bedtime at 01:00: the working day is over at 20:00, the evening starts at 20:30.
        #expect(irregular.dayEndMinute(bedtime: lateBedtime) == 20 * 60)
        let rules = NeedRules.standard.following(irregular, bedtime: lateBedtime)
        #expect(rules.eveningStartMinute == 20 * 60 + 30)
        #expect(rules.gymInviteStartMinute == 21 * 60)
        #expect(rules.gymInviteEndMinute == 22 * 60)
        let gymDays = ActivityDays(gymWeekdays: [2], runWeekday: nil, runStartMinute: 0)
        func activity(at now: Date) -> CompanionActivity? {
            ActivityEngine.activity(
                ActivitySignals(),
                mode: .chill,
                days: gymDays,
                work: irregular,
                bedtime: lateBedtime,
                now: now,
                calendar: calendar
            )
        }
        #expect(activity(at: date(5, 19, 59)) == nil)
        #expect(activity(at: date(5, 20)) == .gymDay)
        let starts = ActivityEngine.startTimes(
            on: date(5, 12),
            days: gymDays,
            work: irregular,
            bedtime: lateBedtime,
            calendar: calendar
        )
        #expect(starts == [date(5, 20)])
    }

    @Test func nothingFollowsWorkHours() {
        let work = irregular
        #expect(work.offWorkNotice(on: date(5, 12), mode: .work, atOffice: true, calendar: calendar) == nil)
        #expect(ModeEngine.scheduledMode(at: date(5, 11), rules: work, calendar: calendar) == .chill)
        let rules = NeedRules.standard.following(work)
        for hour in [12, 14, 18, 20] {
            let moment = MomentEngine.office(
                mode: .work,
                since: date(5, 9),
                now: date(5, hour),
                work: work,
                rules: rules,
                calendar: calendar
            )
            #expect(moment == nil, "\(hour)")
        }
        #expect(MomentEngine.officeTimes(since: date(5, 9), now: date(5, 10), work: work, calendar: calendar).isEmpty)
        // A Monday morning at home is no work morning.
        let home = HomeSignals(since: date(5, 6), workedToday: 0, manualAt: nil)
        #expect(MomentEngine.home(mode: .chill, signals: home, now: date(5, 8), work: work, calendar: calendar) == nil)
        #expect(MomentEngine.home(mode: .chill, signals: home, now: date(5, 8), calendar: calendar) == .morning)
    }

    @Test func leavingTheOfficeEndsWorkAnyTime() {
        let log = ModeLog(changes: [ModeChange(mode: .work, source: .location, at: date(5, 9), deviceID: "t")])
        #expect(irregular.offWorkFromMinute == 0)
        let decision = ModeEngine.decide(.leftOffice, log: log, now: date(5, 12), rules: irregular, calendar: calendar)
        #expect(decision?.mode == .chill)
    }
}
