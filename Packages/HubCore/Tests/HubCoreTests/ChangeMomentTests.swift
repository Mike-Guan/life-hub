import Foundation
import Testing

@testable import HubCore

@MainActor
@Suite struct ChangeMomentTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    // 2026-10-04 and 2026-10-11 are Sundays.
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    @Test func followedCouchAndGymInvitesAreGettingUp() {
        let sent = date(6, 21)
        let moment = ChangeEngine.gotUp(.couchScroll, followed: true, sentAt: sent, deviceID: "t")
        #expect(moment?.kind == .gotUp)
        #expect(moment?.at == sent)
        #expect(ChangeEngine.gotUp(.gymDay, followed: true, sentAt: sent, deviceID: "t") != nil)
        #expect(ChangeEngine.gotUp(.couchScroll, followed: false, sentAt: sent, deviceID: "t") == nil)
        #expect(ChangeEngine.gotUp(.slacking, followed: true, sentAt: sent, deviceID: "t") == nil)
    }

    @Test func reachingTheGymCountsOnlyWhileTheWalkIsOn() {
        let departure = GymDeparture(at: date(6, 20))
        let went = ChangeEngine.wentAfterGo(departure: departure, arrivedAt: date(6, 20, 25), deviceID: "t")
        #expect(went?.kind == .wentAfterGo)
        #expect(ChangeEngine.wentAfterGo(departure: departure, arrivedAt: departure.until, deviceID: "t") == nil)
        #expect(ChangeEngine.wentAfterGo(departure: departure, arrivedAt: date(6, 19), deviceID: "t") == nil)
        #expect(ChangeEngine.wentAfterGo(departure: nil, arrivedAt: date(6, 20, 25), deviceID: "t") == nil)
    }

    @Test func eachMomentIsNotedOnce() throws {
        let suite = "changes-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let moment = try #require(ChangeEngine.gotUp(.couchScroll, followed: true, sentAt: date(6, 21), deviceID: "a"))
        ChangeLog.note(moment, in: defaults)
        ChangeLog.note(moment, in: defaults)
        #expect(ChangeLog.stored(in: defaults).moments == [moment])
    }

    @Test func momentsSavedWithoutContractFieldsStillDecode() throws {
        let old = Data(#"{"moments":[{"id":"gotUp:1","kind":"gotUp","at":"2026-10-06T12:00:00Z"}]}"#.utf8)
        let log = try HubJSON.decoder().decode(ChangeLog.self, from: old)
        #expect(log.moments.first?.schemaVersion == ChangeMoment.currentSchemaVersion)
        #expect(log.moments.first?.updatedBy == "unknown")
    }

    @Test func aKeepsakeEarnedSoonAfterBeingOneAwayIsANearUnlock() {
        let quick = GrowthStore(fileURL: nil, deviceID: "t")
        for (index, day) in [1, 2, 5].enumerated() {
            quick.record(.run5k, source: "r\(index)", at: date(day, 10))
        }
        quick.record(.run5k, source: "r3", at: date(6, 8))
        #expect(ChangeEngine.nearUnlocks(in: quick.ledger) == [date(6, 8)])

        let slow = GrowthStore(fileURL: nil, deviceID: "t")
        for (index, day) in [1, 2, 3, 6].enumerated() {
            slow.record(.run5k, source: "r\(index)", at: date(day, 10))
        }
        #expect(ChangeEngine.nearUnlocks(in: slow.ledger).isEmpty)
    }

    @Test func sundayLineCountsTheWeekAndStaysQuietOtherwise() {
        let sunday = date(11, 10)
        #expect(ChangeEngine.sundayLine(times: [], now: sunday, calendar: calendar) == nil)
        #expect(ChangeEngine.sundayLine(times: [date(6, 21)], now: date(10, 10), calendar: calendar) == nil)
        let one = ChangeEngine.sundayLine(times: [date(6, 21)], now: sunday, calendar: calendar)
        #expect(one == "这周有一次，你真的起来了。我记着。")
        let two = ChangeEngine.sundayLine(times: [date(6, 21), date(9, 20)], now: sunday, calendar: calendar)
        #expect(two == "这周你被我叫起来两次。还行。")
        let times = [date(5, 6), date(6, 21), date(9, 20)]
        let three = ChangeEngine.sundayLine(times: times, now: sunday, calendar: calendar)
        #expect(three == "这周你起来了 3 次。……我可没在数。")
        // Monday 05:00 starts the week; the Sunday before belongs to last week.
        #expect(ChangeEngine.sundayLine(times: [date(4, 20)], now: sunday, calendar: calendar) == nil)
    }
}
