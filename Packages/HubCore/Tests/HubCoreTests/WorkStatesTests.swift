import Foundation
import Testing

@testable import HubCore

@Suite struct WorkStatesTests {
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

    func need(_ signals: NeedSignals, at now: Date) -> NeedReading? {
        NeedEngine.need(signals, now: now, calendar: calendar)
    }

    @Test func workHoursReportsAreSlacking() throws {
        let signals = NeedSignals(slackThresholdAt: date(5, 11), slackSeenAt: date(5, 11, 20))
        let reading = try #require(need(signals, at: date(5, 11, 30)))
        #expect(reading.need == .slacking)
        #expect(reading.since == date(5, 11))
        #expect(reading.until == date(5, 11, 40))
        // 20 minutes without a report ends it.
        #expect(need(signals, at: date(5, 11, 40)) == nil)
        // Reports outside work hours, such as on a Sunday, are not slacking.
        let sunday = NeedSignals(slackThresholdAt: date(4, 15))
        #expect(need(sunday, at: date(4, 15, 5)) == nil)
    }

    @Test func walkingOrAManualSwitchEndsSlacking() {
        var walked = NeedSignals(slackThresholdAt: date(5, 11), slackSeenAt: date(5, 11, 10))
        walked.stillSince = date(5, 11, 15)
        #expect(need(walked, at: date(5, 11, 16)) == nil)
        var switched = NeedSignals(slackThresholdAt: date(5, 11), slackSeenAt: date(5, 11, 10))
        switched.manualSince = date(5, 11, 12)
        #expect(need(switched, at: date(5, 11, 16)) == nil)
    }

    @Test func slackingDoesNotCountAsCouchScrolling() {
        let couch = NeedSignals(scrollThresholdAt: date(5, 11))
        #expect(need(couch, at: date(5, 11, 5))?.need == .couchScroll)
        let work = NeedSignals(slackThresholdAt: date(5, 11))
        #expect(need(work, at: date(5, 11, 5))?.need == .slacking)
    }

    @Test func slackingNoticeSharesTheDailyInvite() {
        let now = date(5, 11)
        let reading = need(NeedSignals(slackThresholdAt: now), at: now)
        let calendar = calendar
        let time = { (last: Date?) in
            NeedEngine.inviteTime(for: reading, now: now, lastInviteAt: last, bedtime: .standard, calendar: calendar)
        }
        #expect(time(nil) == now)
        #expect(time(date(5, 9)) == nil)
        let text = NeedEngine.inviteText(for: .slacking)
        #expect(!text.contains("刷") && text.count <= 14)
    }

    func office(_ since: Date?, at now: Date, mode: Mode? = .work) -> CompanionMoment? {
        MomentEngine.office(mode: mode, since: since, now: now, calendar: calendar)
    }

    @Test func drowsyFromTwoOrThreeHoursIn() {
        // Arriving at 9:30: drowsy from 12:30, three hours in, for two hours.
        #expect(office(date(5, 9, 30), at: date(5, 12, 29)) == nil)
        #expect(office(date(5, 9, 30), at: date(5, 12, 30)) == .drowsy)
        #expect(office(date(5, 9, 30), at: date(5, 14, 30)) == nil)
        // Arriving at noon: drowsy at 14:00.
        #expect(office(date(5, 12), at: date(5, 14)) == .drowsy)
        #expect(office(date(5, 12), at: date(5, 16)) == nil)
    }

    @Test func overtimeAfterSevenAtTheOffice() {
        #expect(office(date(5, 9, 30), at: date(5, 18, 14)) == nil)
        #expect(office(date(5, 9, 30), at: date(5, 19)) == .overtime)
        // Both need the office and work mode.
        #expect(office(nil, at: date(5, 19)) == nil)
        #expect(office(date(5, 9, 30), at: date(5, 19), mode: .chill) == nil)
        #expect(office(nil, at: date(5, 14)) == nil)
    }

    @Test func momentsComeInOrder() {
        func moment(_ hustle: SideHustle?, _ need: CompanionNeed?, departing: Bool = false) -> CompanionMoment? {
            MomentEngine.moment(
                mode: hustle == nil ? .work : .money,
                sideHustle: hustle,
                activity: nil,
                need: need,
                departing: departing,
                officeSince: date(5, 9),
                now: date(5, 19, 30),
                calendar: calendar
            )
        }
        #expect(moment(.shooting, .slacking) == .shooting)
        #expect(moment(nil, nil, departing: true) == .heading)
        #expect(moment(nil, .slacking) == .slacking)
        #expect(moment(nil, nil) == .overtime)
    }

    @Test func officeTimesCoverTheDay() {
        let times = MomentEngine.officeTimes(since: date(5, 9, 30), now: date(5, 10), calendar: calendar)
        #expect(times == [date(5, 12, 30), date(5, 14, 30), date(5, 19), date(5, 18, 15), date(5, 19)])
        #expect(MomentEngine.officeTimes(since: nil, now: date(5, 10)).isEmpty)
    }

    @Test func workStatesHaveLines() {
        #expect(HakuLines.scene(for: .slacking) == .slacking)
        #expect(HakuLines.scene(for: .drowsy) == .drowsy)
        #expect(HakuLines.scene(for: .overtime) == .overtime)
        #expect(HakuLines.scene(for: .vibeCoding) == nil)
        #expect(HakuLines.scene(mode: .work, need: .slacking, energy: nil, bedtime: .off) == .slacking)
    }
}
