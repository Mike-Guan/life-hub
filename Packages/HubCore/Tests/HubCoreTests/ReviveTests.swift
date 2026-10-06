import Foundation
import Testing

@testable import HubCore

@Suite struct ReviveTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    func revived(switchedAt: Date?, seen: Date?, atHome: Bool = true, now: Date) -> CompanionEvent? {
        ReviveEngine.revived(switchedAt: switchedAt, scrollSeenAt: seen, atHome: atHome, now: now, calendar: calendar)
    }

    @Test func getsUpWhenTheSwitchEndsCouchScrolling() {
        let event = revived(switchedAt: date(6, 21), seen: date(6, 20, 50), now: date(6, 21, 5))
        #expect(event == .revived(id: date(6, 5).ISO8601Format()))
    }

    @Test func needsCouchScrollingRightBeforeTheSwitch() {
        // Couch scrolling ends 20 minutes after the last report.
        #expect(revived(switchedAt: date(6, 21), seen: date(6, 20, 40), now: date(6, 21)) == nil)
        #expect(revived(switchedAt: date(6, 21), seen: nil, now: date(6, 21)) == nil)
        // A report after the switch is scrolling during it, not before it.
        #expect(revived(switchedAt: date(6, 21), seen: date(6, 21, 10), now: date(6, 21, 15)) == nil)
        #expect(revived(switchedAt: date(6, 21), seen: date(6, 20, 50), atHome: false, now: date(6, 21)) == nil)
    }

    @Test func playsOnlySoonAfterTheSwitch() {
        #expect(revived(switchedAt: date(6, 21), seen: date(6, 20, 50), now: date(6, 21, 29)) != nil)
        #expect(revived(switchedAt: date(6, 21), seen: date(6, 20, 50), now: date(6, 21, 30)) == nil)
        #expect(revived(switchedAt: date(6, 21), seen: date(6, 20, 50), now: date(6, 20, 59)) == nil)
        #expect(revived(switchedAt: nil, seen: date(6, 20, 50), now: date(6, 21)) == nil)
    }

    @Test func oneIdPerHubDay() {
        let evening = revived(switchedAt: date(6, 20), seen: date(6, 19, 55), now: date(6, 20))
        let bath = revived(switchedAt: date(6, 22, 45), seen: date(6, 22, 40), now: date(6, 22, 45))
        let lateNight = revived(switchedAt: date(7, 1), seen: date(7, 0, 50), now: date(7, 1))
        #expect(evening == bath)
        #expect(bath == lateNight)
    }

    @Test func switchIsVibeCodingOrTheBath() {
        let coding = ModeChange(mode: .money, source: .manual, at: date(6, 20), deviceID: "test")
        var shooting = coding
        shooting.tag = SideHustle.shooting.rawValue
        let chill = ModeChange(mode: .chill, source: .manual, at: date(6, 19), deviceID: "test")
        let bath = DateInterval(start: date(6, 22, 45), duration: 30 * 60)
        #expect(ReviveEngine.switchedAt(change: coding, bath: nil) == date(6, 20))
        #expect(ReviveEngine.switchedAt(change: shooting, bath: nil) == nil)
        #expect(ReviveEngine.switchedAt(change: chill, bath: nil) == nil)
        #expect(ReviveEngine.switchedAt(change: chill, bath: bath) == date(6, 22, 45))
        #expect(ReviveEngine.switchedAt(change: coding, bath: bath) == date(6, 22, 45))
        #expect(ReviveEngine.switchedAt(change: nil, bath: nil) == nil)
    }
}
