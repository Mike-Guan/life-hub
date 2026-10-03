import Foundation
import Testing

@testable import HubCore

@Suite struct SleepTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    func asleep(_ start: Date, _ end: Date) -> SleepInterval {
        SleepInterval(start: start, end: end)
    }

    @Test func windowStartsAtFiveInTheEveningBefore() {
        let window = SleepNight.window(for: date(4, 8), calendar: calendar)
        #expect(window.start == date(3, 17))
        #expect(window.end == date(4, 8))
        #expect(SleepNight.window(for: date(4, 18), calendar: calendar).end == date(4, 14))
    }

    @Test func afternoonNapsAreLeftOut() throws {
        let intervals = [asleep(date(4, 0), date(4, 7)), asleep(date(4, 15), date(4, 16))]
        let night = try #require(SleepNight.from(intervals, now: date(4, 20), calendar: calendar))
        #expect(night.minutes == 7 * 60)
        #expect(night.endedAt == date(4, 7))
    }

    @Test func overlappingSourcesCountOnce() throws {
        let intervals = [
            asleep(date(3, 23, 30), date(4, 3)),
            asleep(date(4, 2), date(4, 6, 30)),  // overlaps the first by an hour
            asleep(date(4, 4), date(4, 5)),  // inside the second
        ]
        let night = try #require(SleepNight.from(intervals, now: date(4, 9), calendar: calendar))
        #expect(night.minutes == 7 * 60)
        #expect(night.endedAt == date(4, 6, 30))
    }

    @Test func gapsAreNotCounted() throws {
        let intervals = [asleep(date(4, 0), date(4, 3)), asleep(date(4, 4), date(4, 7))]
        let night = try #require(SleepNight.from(intervals, now: date(4, 9), calendar: calendar))
        #expect(night.minutes == 6 * 60)
    }

    @Test func sleepBeforeTheWindowIsClipped() throws {
        let long = [asleep(date(3, 15), date(4, 6))]
        let night = try #require(SleepNight.from(long, now: date(4, 9), calendar: calendar))
        #expect(night.minutes == 13 * 60)
    }

    @Test func noSleepEndingTodayMeansNoNight() {
        #expect(SleepNight.from([], now: date(4, 9), calendar: calendar) == nil)
        #expect(SleepNight.from([asleep(date(3, 18), date(3, 19))], now: date(4, 9), calendar: calendar) == nil)
    }

    @Test func idDependsOnlyOnTheNight() throws {
        let early = try #require(SleepNight.from([asleep(date(4, 0), date(4, 6))], now: date(4, 7), calendar: calendar))
        let late = try #require(SleepNight.from([asleep(date(4, 1), date(4, 8))], now: date(4, 12), calendar: calendar))
        let next = try #require(SleepNight.from([asleep(date(5, 1), date(5, 8))], now: date(5, 9), calendar: calendar))
        #expect(early.id == late.id)
        #expect(early.id != next.id)
    }

    @MainActor @Test func reimportUpdatesTheSameEvent() throws {
        let store = EnergyStore(fileURL: nil, deviceID: "iphone")
        let first = try #require(SleepNight.from([asleep(date(4, 1), date(4, 6))], now: date(4, 7), calendar: calendar))
        let more = try #require(SleepNight.from([asleep(date(4, 1), date(4, 8))], now: date(4, 9), calendar: calendar))
        #expect(store.record(first, now: date(4, 7)))
        #expect(!store.record(first, now: date(4, 8)))
        #expect(store.record(more, now: date(4, 9)))
        #expect(store.log.events.count == 1)
        #expect(store.log.events[0].sleepMinutes == 7 * 60)
        #expect(store.log.events[0].updatedAt == date(4, 9))
        #expect(store.reading(now: date(4, 10), calendar: calendar)?.level == .okay)
    }
}
