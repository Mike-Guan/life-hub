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
}
