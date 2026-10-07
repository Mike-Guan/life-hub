import Foundation
import Testing

@testable import HubCore

@Suite struct ReturnReplayTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func date(_ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour)) ?? .distantPast
    }

    func earned(_ win: Win, at: Date) -> CanEntry {
        CanEntry(id: UUID(), kind: .earned, at: at, cans: win.cans, win: win, deviceID: "t")
    }

    func night(_ day: Int, minutes: Int) -> SleepNight {
        SleepNight(id: UUID(), minutes: minutes, endedAt: date(day, 7))
    }

    @Test func nightsAreReadBackPerHubDay() {
        // Two nights while away, each 23:00 to 07:00, and a nap that doesn't count.
        let intervals = [
            SleepInterval(start: date(2, 23), end: date(3, 7)),
            SleepInterval(start: date(3, 23), end: date(4, 7)),
            SleepInterval(start: date(4, 15), end: date(4, 16)),
        ]
        let window = SleepNight.window(from: date(2), to: date(5), calendar: calendar)
        #expect(window.start == date(1, 17))
        let nights = SleepNight.nights(intervals, from: date(2), to: date(5), calendar: calendar)
        #expect(nights.map(\.minutes) == [480, 480])
        #expect(Set(nights.map(\.id)).count == 2)
    }

    func replay(
        seen: Date?,
        now: Date,
        lastBox: Date? = nil,
        entries: [CanEntry] = [],
        nights: [SleepNight] = []
    ) -> ReturnReplay? {
        ReturnReplay.make(
            lastSeen: seen,
            lastBox: lastBox,
            ledger: CanLedger(entries: entries),
            nights: nights,
            log: ModeLog(changes: []),
            now: now,
            calendar: calendar
        )
    }

    @Test func tiersFollowTheHubDaysAway() {
        #expect(replay(seen: nil, now: date(10)) == nil)
        #expect(replay(seen: date(1), now: date(3)) == nil)
        #expect(replay(seen: date(1), now: date(4))?.tier == .glance)
        #expect(replay(seen: date(1), now: date(8))?.tier == .glance)
        #expect(replay(seen: date(1), now: date(9))?.tier == .box)
        // 02:00 still belongs to the day before, which starts at 05:00.
        #expect(replay(seen: date(1), now: date(4, 2)) == nil)
    }

    @Test func theBoxPlaysAtMostOnceInThirtyDays() {
        #expect(replay(seen: date(1), now: date(20), lastBox: date(1))?.tier == .glance)
        let longAgo = date(20).addingTimeInterval(-ReturnReplay.boxEvery)
        #expect(replay(seen: date(1), now: date(20), lastBox: longAgo)?.tier == .box)
    }

    @Test func nothingRecordedIsTheQuietVersion() throws {
        let quiet = try #require(replay(seen: date(1), now: date(10)))
        #expect(quiet.isQuiet)
        #expect(quiet.line == "……坐。")
        #expect(quiet.cards.isEmpty)
    }

    @Test func cardsSayWhatHappenedInOrder() throws {
        let entries = [
            earned(.gym, at: date(2)),
            earned(.boxing, at: date(3)),
            earned(.boxing, at: date(5)),
            earned(.run5k, at: date(6)),
            earned(.plannedTask, at: date(6)),
            earned(.daylight, at: date(7)),
        ]
        let nights = [night(3, minutes: 480), night(4, minutes: 300)]
        let box = try #require(replay(seen: date(1), now: date(10), entries: entries, nights: nights))
        #expect(box.tier == .box)
        #expect(box.line == "……又不是在等你。")
        let texts = ["打了 2 次拳。", "跑了 1 次 5 公里。", "去了 1 次健身房。", "有一天睡得挺好。", "做完了 1 件提前定好的事。"]
        #expect(box.cards.map(\.text) == texts)
        #expect(box.cans == 5 + 5 + 5 + 3 + 1 + 1)
        let glance = try #require(replay(seen: date(1), now: date(5, 13), entries: entries, nights: nights))
        #expect(glance.line == "哦，回来了。")
        #expect(glance.cards.count == 3)
    }

    @Test func onlyEntriesWhileAwayCount() throws {
        let entries = [
            earned(.boxing, at: date(1, 8)),
            CanEntry(id: UUID(), kind: .bought, at: date(3), cans: 10, itemID: "room.plant", deviceID: "t"),
        ]
        let back = try #require(replay(seen: date(1), now: date(10), entries: entries))
        #expect(back.isQuiet)
        #expect(back.cans == 0)
    }

    @Test func newTracesAndKeepsakesGetCards() throws {
        var entries = (0..<4).map { earned(.boxing, at: date(1, 8).addingTimeInterval(Double($0) * 60)) }
        entries.append(earned(.boxing, at: date(3)))
        let up = "celebrate.up"
        let keepsake = CanEntry(id: UUID(), kind: .granted, at: date(9, 9), cans: 0, itemID: up, deviceID: "t")
        entries.append(keepsake)
        let back = try #require(replay(seen: date(1), now: date(10), entries: entries))
        #expect(back.cards.map(\.kind) == [.boxing, .trace, .keepsake])
        #expect(back.cards[1].text == "拳套磨旧了。")
        #expect(back.cards[1].item == "wornGloves")
        #expect(back.cards[2].text == "拿到了起身庆祝。")
    }

    @Test func severalGoodNightsAreSaidLoosely() {
        let nights = (2..<5).map { night($0, minutes: 470) }
        let cards = ReturnCard.cards(earned: [], granted: [], nights: nights, traces: [])
        #expect(cards.map(\.text) == ["有几天睡得挺好。"])
        #expect(cards.first?.count == 3)
    }

    @Test func theReplayTravelsAsAnEvent() throws {
        let back = try #require(replay(seen: date(1), now: date(10)))
        let event = CompanionEvent.welcomeBack(id: "a", replay: back)
        #expect(event != .welcomeBack(id: "b", replay: back))
    }

    @Test func theLastBoxIsStored() throws {
        let defaults = try #require(UserDefaults(suiteName: "ReturnReplayTests"))
        defaults.removePersistentDomain(forName: "ReturnReplayTests")
        #expect(ReturnLog.lastBox(in: defaults) == nil)
        ReturnLog.markBox(at: date(5), in: defaults)
        #expect(ReturnLog.lastBox(in: defaults) == date(5))
    }

    @Test func oneStayAwayIsOneReturn() throws {
        let defaults = try #require(UserDefaults(suiteName: "ReturnLogSince"))
        defaults.removePersistentDomain(forName: "ReturnLogSince")
        #expect(ReturnLog.since(away: nil, in: defaults) == nil)
        #expect(ReturnLog.since(away: date(1), in: defaults) == date(1))
        // Active again after Control Center, with no stay in the background.
        #expect(ReturnLog.since(away: date(1), in: defaults) == nil)
        #expect(ReturnLog.since(away: date(9), in: defaults) == date(9))
    }

    @Test func aPendingReturnWaitsForALaterOpen() throws {
        let defaults = try #require(UserDefaults(suiteName: "ReturnLogPending"))
        defaults.removePersistentDomain(forName: "ReturnLogPending")
        #expect(ReturnLog.since(away: date(1), in: defaults) == date(1))
        ReturnLog.setPending(date(1), in: defaults)
        #expect(ReturnLog.since(away: date(1), in: defaults) == date(1))
        #expect(ReturnLog.since(away: date(4), in: defaults) == date(1))
        ReturnLog.setPending(nil, in: defaults)
        #expect(ReturnLog.since(away: date(4), in: defaults) == nil)
    }
}
