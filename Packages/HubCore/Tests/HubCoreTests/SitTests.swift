import Foundation
import Testing

@testable import HubCore

@Suite struct SitTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func date(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: hour, minute: minute)) ?? .distantPast
    }

    func hours(from hour: Int, _ stood: [Bool]) -> [StandHour] {
        stood.enumerated().map { StandHour(start: date(hour + $0.offset), stood: $0.element) }
    }

    @Test func twoIdleHoursMakeHakuStiff() {
        let state = SitEngine.state(hours(from: 10, [true, false, false]), now: date(13, 10))
        #expect(state.stiffSince == date(11))
        #expect(state.stoodAt == nil)
        #expect(state.isStiff(mode: .work, at: date(13, 30)))
        #expect(state.isStiff(mode: .money, at: date(13, 30)))
        #expect(!state.isStiff(mode: .chill, at: date(13, 30)))
        #expect(!state.isStiff(mode: nil, at: date(13, 30)))
    }

    @Test func oneIdleHourIsNotEnough() {
        let state = SitEngine.state(hours(from: 10, [true, true, false]), now: date(13, 10))
        #expect(state.stiffSince == nil)
    }

    @Test func theCurrentHourDoesNotCountYet() {
        // The 13:00 hour isn't over at 13:10, so only 12:00 is idle.
        let state = SitEngine.state(hours(from: 11, [true, false, false]), now: date(13, 10))
        #expect(state.stiffSince == nil)
    }

    @Test func noRecentStandHourMeansNoJudgement() {
        #expect(SitEngine.state([], now: date(13)) == SitState(checkedAt: date(13)))
        // The last hour ended at 12:00; by 14:00 it is too old to react to.
        let old = SitEngine.state(hours(from: 10, [false, false]), now: date(14))
        #expect(old.stiffSince == nil)
    }

    @Test func aGapBreaksTheStretch() {
        let gap = [StandHour(start: date(9), stood: false), StandHour(start: date(11), stood: false)]
        #expect(SitEngine.state(gap, now: date(12, 5)).stiffSince == nil)
    }

    @Test func standingAfterTwoIdleHoursStretchesOnce() {
        let state = SitEngine.state(hours(from: 10, [false, false, true]), now: date(13, 5))
        #expect(state.stiffSince == nil)
        #expect(state.stoodAt == date(12))
        #expect(state.stretched(at: date(13, 5)) == .stretched(id: date(12).ISO8601Format()))
        #expect(state.stretched(at: date(14)) == nil)
        #expect(!state.isStiff(mode: .work, at: date(13, 5)))
    }

    @Test func standingAfterOneIdleHourIsNoStretch() {
        let state = SitEngine.state(hours(from: 10, [true, false, true]), now: date(13, 5))
        #expect(state.stoodAt == nil)
    }

    @Test func stiffFadesWhenTheReadingGetsOld() {
        let state = SitEngine.state(hours(from: 10, [false, false]), now: date(12, 5))
        #expect(state.isStiff(mode: .work, at: date(14)))
        #expect(!state.isStiff(mode: .work, at: date(14, 5)))
    }

    @Test func stiffComesFirstExceptScrollingAtWork() {
        let stiff = MomentEngine.moment(
            mode: .money,
            sideHustle: .vibeCoding,
            activity: nil,
            need: nil,
            departing: false,
            officeSince: nil,
            stiff: true,
            now: date(15)
        )
        #expect(stiff == .stiff)
        let slacking = MomentEngine.moment(
            mode: .work,
            sideHustle: nil,
            activity: nil,
            need: .slacking,
            departing: false,
            officeSince: nil,
            stiff: true,
            now: date(15)
        )
        #expect(slacking == .slacking)
    }

    @Test func stateRoundTripsThroughDefaults() throws {
        let defaults = try #require(UserDefaults(suiteName: "sit-\(UUID().uuidString)"))
        #expect(SitState.stored(in: defaults) == nil)
        let state = SitState(checkedAt: date(13), stiffSince: date(11))
        state.store(in: defaults)
        #expect(SitState.stored(in: defaults) == state)
    }

    // 2026-10-06 is a Tuesday, a work day; default work hours are 9:30 to 18:30.
    func stiff() -> SitState {
        SitState(checkedAt: date(13, 10), stiffSince: date(11))
    }

    @Test func sittingIsANeedInWorkHoursInWorkOrSideHustle() {
        let signals = NeedSignals(sit: stiff(), mode: .work)
        let reading = NeedEngine.need(signals, now: date(13, 20), calendar: calendar)
        #expect(reading?.need == .sitting)
        #expect(reading?.since == date(13))
        #expect(reading?.until == date(15, 10))
        let money = NeedSignals(sit: stiff(), mode: .money)
        #expect(NeedEngine.need(money, now: date(13, 20), calendar: calendar)?.need == .sitting)
        let chill = NeedSignals(sit: stiff(), mode: .chill)
        #expect(NeedEngine.need(chill, now: date(13, 20), calendar: calendar) == nil)
    }

    @Test func sittingAfterWorkHoursIsNoNeed() {
        let late = SitState(checkedAt: date(19, 10), stiffSince: date(17))
        let signals = NeedSignals(sit: late, mode: .money)
        #expect(NeedEngine.need(signals, now: date(19, 20), calendar: calendar) == nil)
    }

    @Test func sittingInviteGoesOutAtOnceWithItsOwnText() {
        let reading = NeedEngine.need(NeedSignals(sit: stiff(), mode: .work), now: date(13, 20), calendar: calendar)
        let at = NeedEngine.inviteTime(
            for: reading,
            now: date(13, 20),
            lastInviteAt: nil,
            bedtime: .standard,
            calendar: calendar
        )
        #expect(at == date(13, 20))
        #expect(NeedEngine.inviteText(for: .sitting) == "起来。我先起了。")
        // Shares the one invite a day with scrolling at work.
        let again = NeedEngine.inviteTime(
            for: reading,
            now: date(13, 20),
            lastInviteAt: date(10),
            bedtime: .standard,
            calendar: calendar
        )
        #expect(again == nil)
    }

    @Test func sittingNeedShowsStiff() {
        let moment = MomentEngine.moment(
            mode: .work,
            sideHustle: nil,
            activity: nil,
            need: .sitting,
            departing: false,
            officeSince: nil,
            now: date(15)
        )
        #expect(moment == .stiff)
    }

    @Test func sittingInviteIsJudgedByTheStandHours() {
        let sent = date(13, 20)
        func verdict(_ sit: SitState?) -> Bool? {
            let signals = NeedSignals(sit: sit)
            return NudgeBackoff.followed(.sitting, sentAt: sent, signals: signals, departedAt: nil, now: date(15))
        }
        #expect(verdict(SitState(checkedAt: date(14, 50), stoodAt: date(13))) == true)
        #expect(verdict(SitState(checkedAt: date(14, 55), stiffSince: date(11))) == false)
        // Too early to tell, or no data: no verdict.
        #expect(verdict(SitState(checkedAt: date(14), stiffSince: date(11))) == nil)
        #expect(verdict(nil) == nil)
        #expect(verdict(SitState(checkedAt: date(14, 55))) == nil)
    }
}
