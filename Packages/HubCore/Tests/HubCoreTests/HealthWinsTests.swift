import Foundation
import Testing

@testable import HubCore

@MainActor
@Suite struct HealthWinsTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    func sleep(_ start: Date, _ end: Date) -> SleepInterval {
        SleepInterval(start: start, end: end)
    }

    let schedule = BedtimeSchedule.standard

    @Test func daylightEarnsOnceAHubDayFromAQuarterHour() {
        #expect(Win.daylight(14 * 60, now: date(14, 12), calendar: calendar) == nil)
        let noon = Win.daylight(15 * 60, now: date(14, 12), calendar: calendar)
        #expect(noon?.win == .daylight)
        #expect(noon?.at == date(14, 12))
        let evening = Win.daylight(40 * 60, now: date(14, 22), calendar: calendar)
        #expect(evening?.source == noon?.source)
        // Before 05:00 is still the day before.
        let lateNight = Win.daylight(40 * 60, now: date(15, 2), calendar: calendar)
        #expect(lateNight?.source == noon?.source)
        #expect(Win.daylight(40 * 60, now: date(15, 9), calendar: calendar)?.source != noon?.source)
    }

    @Test func fallingAsleepByHalfAnHourAfterBedtimeEarns() {
        let night = [sleep(date(13, 23, 55), date(14, 7))]
        let win = Win.earlySleep(night, schedule: schedule, now: date(14, 9), calendar: calendar)
        #expect(win?.win == .earlySleep)
        // Dated at the set bedtime, not at the time read from Health.
        #expect(win?.at == date(13, 23, 30))
        #expect(win?.source == Win.earlySleep.source(at: date(14, 5), calendar: calendar))
        let early = [sleep(date(13, 22), date(14, 6))]
        #expect(Win.earlySleep(early, schedule: schedule, now: date(14, 9), calendar: calendar) != nil)
    }

    @Test func fallingAsleepLateEarnsNothing() {
        let late = [sleep(date(14, 0, 1), date(14, 8))]
        #expect(Win.earlySleep(late, schedule: schedule, now: date(14, 9), calendar: calendar) == nil)
        #expect(Win.earlySleep([], schedule: schedule, now: date(14, 9), calendar: calendar) == nil)
    }

    @Test func noBedtimeSetEarnsNothing() {
        let night = [sleep(date(13, 22), date(14, 6))]
        #expect(Win.earlySleep(night, schedule: .unset, now: date(14, 9), calendar: calendar) == nil)
    }

    @Test func aBedtimeWithTheReminderOffStillEarns() throws {
        let defaults = try #require(UserDefaults(suiteName: "HealthWinsTests.reminderOff"))
        defaults.removePersistentDomain(forName: "HealthWinsTests.reminderOff")
        schedule.store(in: defaults)
        BedtimeSchedule.setRemindsAtBedtime(false, in: defaults)
        let stored = BedtimeSchedule.stored(in: defaults)
        let night = [sleep(date(13, 23), date(14, 7))]
        #expect(Win.earlySleep(night, schedule: stored, now: date(14, 9), calendar: calendar) != nil)
    }

    @Test func anEveningNapDoesNotCountAsGoingToBed() {
        let night = [
            sleep(date(13, 19), date(13, 19, 40)),
            sleep(date(14, 1), date(14, 3)),
            sleep(date(14, 3, 20), date(14, 8)),
        ]
        #expect(Win.earlySleep(night, schedule: schedule, now: date(14, 9), calendar: calendar) == nil)
    }

    @Test func aBedtimeAfterMidnightIsTheSameNight() {
        let schedule = BedtimeSchedule(startMinute: 30, endMinute: 6 * 60)
        let night = [sleep(date(14, 0, 50), date(14, 8))]
        let win = Win.earlySleep(night, schedule: schedule, now: date(14, 9), calendar: calendar)
        #expect(win?.at == date(14, 0, 30))
    }

    @Test func eachNightEarnsOnce() {
        let store = GrowthStore(fileURL: nil, deviceID: "t")
        let night = [sleep(date(13, 23), date(14, 7))]
        for now in [date(14, 9), date(14, 13)] {
            let win = Win.earlySleep(night, schedule: schedule, now: now, calendar: calendar)
            if let win { store.record(win.win, source: win.source, at: win.at) }
        }
        #expect(store.ledger.count(.earlySleep) == 1)
    }
}
