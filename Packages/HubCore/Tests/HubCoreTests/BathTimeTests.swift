import Foundation
import Testing

@testable import HubCore

@Suite struct BathTimeTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    func on(_ at: Date, mode: Mode? = .chill, home: Bool = true, done: Date? = nil) -> Bool {
        BathTime.isOn(at: at, bedtime: .standard, mode: mode, atHome: home, doneAt: done, calendar: calendar)
    }

    @Test func runsFrom45MinutesBeforeBedtimeForHalfAnHour() {
        #expect(!on(date(5, 22, 44)))
        #expect(on(date(5, 22, 45)))
        #expect(on(date(5, 23, 14)))
        #expect(!on(date(5, 23, 15)))
        #expect(!on(date(5, 23, 30)))
    }

    @Test func onlyAtHomeInChill() {
        #expect(!on(date(5, 23), mode: .work))
        #expect(!on(date(5, 23), mode: .money))
        #expect(!on(date(5, 23), mode: nil))
        #expect(!on(date(5, 23), home: false))
    }

    @Test func aTapEndsItForThatEvening() {
        #expect(!on(date(5, 23), done: date(5, 22, 50)))
        #expect(on(date(5, 23), done: date(4, 22, 50)))
        #expect(on(date(6, 23), done: date(5, 22, 50)))
    }

    @Test func bedtimeAfterMidnightAndTimelineTimes() {
        let late = BedtimeSchedule(startMinute: 30, endMinute: 6 * 60)
        let lateOn = { (at: Date) in
            BathTime.isOn(at: at, bedtime: late, mode: .chill, atHome: true, doneAt: nil, calendar: self.calendar)
        }
        #expect(lateOn(date(5, 23, 50)))
        #expect(lateOn(date(6, 0, 10)))
        #expect(!lateOn(date(6, 0, 15)))
        let times = BathTime.times(after: date(5, 12), bedtime: .standard, calendar: calendar)
        #expect(times == [date(5, 22, 45), date(5, 23, 15)])
    }

    @Test func tapsAreStored() throws {
        let defaults = try #require(UserDefaults(suiteName: "BathTimeTests"))
        defaults.removePersistentDomain(forName: "BathTimeTests")
        #expect(BathTime.doneAt(in: defaults) == nil)
        BathTime.markDone(at: date(5, 22, 50), in: defaults)
        #expect(BathTime.doneAt(in: defaults) == date(5, 22, 50))
    }
}
