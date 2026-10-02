import Foundation
import Testing
@testable import HubCore

@Suite struct ModeLogTests {
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func change(_ mode: Mode, _ at: Date, source: ModeChange.Source = .manual) -> ModeChange {
        ModeChange(mode: mode, source: source, at: at, deviceID: "test")
    }

    @Test func segmentsRunUntilNextChangeAndNow() {
        let log = ModeLog(changes: [change(.work, date(2, 9)), change(.chill, date(2, 18))])
        let segments = log.segments(on: date(2, 12), now: date(2, 20), calendar: calendar)
        #expect(segments.map(\.mode) == [.work, .chill])
        #expect(segments[0].duration == 9 * 3600)
        #expect(segments[1].duration == 2 * 3600)
        #expect(segments[1].isOngoing)
        #expect(!segments[0].isOngoing)
    }

    @Test func modeCarriedOverFromYesterdayStartsAtMidnight() {
        let log = ModeLog(changes: [change(.chill, date(1, 22)), change(.work, date(2, 9))])
        let segments = log.segments(on: date(2, 12), now: date(2, 10), calendar: calendar)
        #expect(segments.map(\.mode) == [.chill, .work])
        #expect(segments[0].start == date(2, 0))
        #expect(segments[0].duration == 9 * 3600)
    }

    @Test func pastDayEndsAtMidnightAndIsNotOngoing() {
        let log = ModeLog(changes: [change(.boxing, date(1, 19))])
        let segments = log.segments(on: date(1, 12), now: date(2, 8), calendar: calendar)
        #expect(segments.count == 1)
        #expect(segments[0].end == date(2, 0))
        #expect(!segments[0].isOngoing)
    }

    @Test func deletedChangesAreIgnored() {
        var removed = change(.money, date(2, 12))
        removed.deletedAt = date(2, 13)
        let log = ModeLog(changes: [change(.work, date(2, 9)), removed])
        #expect(log.current?.mode == .work)
        let work = log.totals(on: date(2, 12), now: date(2, 14), calendar: calendar)[.work] ?? 0
        #expect(abs(work - 5 * 3600) < 0.001)
    }

    @Test func futureDayHasNoSegments() {
        let log = ModeLog(changes: [change(.work, date(2, 9))])
        #expect(log.segments(on: date(3, 12), now: date(2, 10), calendar: calendar).isEmpty)
    }
}
