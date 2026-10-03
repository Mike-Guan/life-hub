import Foundation
import Testing

@testable import HubCore

@Suite struct NeedEngineTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    // 2026-10-04 is a Sunday, 2026-10-05 a Monday.
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    func need(_ signals: NeedSignals, at now: Date) -> NeedReading? {
        NeedEngine.need(signals, now: now, calendar: calendar)
    }

    func workout(_ kind: WorkoutSummary.Kind, _ start: Date, minutes: Double, meters: Double? = nil) -> WorkoutSummary {
        WorkoutSummary(id: "\(kind)-\(start)", kind: kind, start: start, end: start + minutes * 60, meters: meters)
    }

    @Test func noSignalsMeansNoNeed() {
        #expect(need(NeedSignals(), at: date(5, 21)) == nil)
    }

    @Test func screenTimeThresholdIsCouchScrolling() throws {
        let reached = date(5, 20, 10)
        let reading = try #require(need(NeedSignals(scrollThresholdAt: reached), at: date(5, 20, 30)))
        #expect(reading.need == .couchScroll)
        #expect(reading.since == reached)
        #expect(!reading.reasons.isEmpty)
    }

    @Test func yesterdaysThresholdDoesNotCount() {
        #expect(need(NeedSignals(scrollThresholdAt: date(4, 22)), at: date(5, 20)) == nil)
        #expect(need(NeedSignals(scrollThresholdAt: date(5, 21)), at: date(5, 20)) == nil)
    }

    @Test func stillAtHomeInTheEveningIsCouchScrolling() throws {
        let signals = NeedSignals(atHomeSince: date(5, 18, 45), stillSince: date(5, 19, 10))
        #expect(need(signals, at: date(5, 20, 9)) == nil)
        let reading = try #require(need(signals, at: date(5, 20, 10)))
        #expect(reading.need == .couchScroll)
        #expect(reading.since == date(5, 20, 10))
        #expect(reading.reasons == ["在家 60 分钟没怎么动了，我也瘫着"])
    }

    @Test func stillBeforeTheEveningStartsCountingAtTheEvening() throws {
        let signals = NeedSignals(atHomeSince: date(5, 15), stillSince: date(5, 16))
        #expect(need(signals, at: date(5, 18, 59)) == nil)
        #expect(try #require(need(signals, at: date(5, 19))).since == date(5, 19))
    }

    @Test func fallbackNeedsHomeAndStillness() {
        #expect(need(NeedSignals(stillSince: date(5, 18)), at: date(5, 21)) == nil)
        #expect(need(NeedSignals(atHomeSince: date(5, 18)), at: date(5, 21)) == nil)
    }

    @Test func sundayMorningIsBoxingWarmup() throws {
        #expect(need(NeedSignals(), at: date(4, 8, 59)) == nil)
        let reading = try #require(need(NeedSignals(), at: date(4, 9)))
        #expect(reading.need == .boxingWarmup)
        #expect(reading.since == date(4, 9))
        #expect(need(NeedSignals(), at: date(4, 12)) == nil)
        #expect(need(NeedSignals(), at: date(5, 9, 30)) == nil)
    }

    @Test func boxingWarmupEndsAtTheGymOrAfterBoxing() {
        #expect(need(NeedSignals(atGym: true), at: date(4, 9, 50)) == nil)
        let boxed = NeedSignals(workouts: [workout(.boxing, date(4, 7), minutes: 45)])
        #expect(need(boxed, at: date(4, 9, 30)) == nil)
        let yesterday = NeedSignals(workouts: [workout(.boxing, date(3, 10), minutes: 45)])
        #expect(need(yesterday, at: date(4, 9, 30))?.need == .boxingWarmup)
    }

    @Test func couchScrollingComesBeforeBoxing() {
        let signals = NeedSignals(scrollThresholdAt: date(4, 9, 15))
        #expect(need(signals, at: date(4, 9, 30))?.need == .couchScroll)
    }

    @Test func inviteWaitsForTheNeedToLast() {
        let couch = NeedReading(need: .couchScroll, since: date(5, 20), reasons: [])
        let invite = { (now: Date, last: Date?, bedtime: Bedtime) in
            NeedEngine.shouldInvite(couch, now: now, lastInviteAt: last, bedtime: bedtime, calendar: self.calendar)
        }
        #expect(!invite(date(5, 20, 59), nil, .off))
        #expect(invite(date(5, 21), nil, .off))
        #expect(!invite(date(5, 21), nil, .on))

        let boxing = NeedReading(need: .boxingWarmup, since: date(4, 9), reasons: [])
        #expect(!NeedEngine.shouldInvite(boxing, now: date(4, 9, 29), lastInviteAt: nil, bedtime: .off))
        #expect(NeedEngine.shouldInvite(boxing, now: date(4, 9, 30), lastInviteAt: nil, bedtime: .off))
        #expect(!NeedEngine.shouldInvite(nil, now: date(4, 9, 30), lastInviteAt: nil, bedtime: .off))
    }

    @Test func atMostOneInviteADayWithACooldown() {
        let couch = NeedReading(need: .couchScroll, since: date(5, 20), reasons: [])
        let invite = { (now: Date, last: Date) in
            NeedEngine.shouldInvite(couch, now: now, lastInviteAt: last, bedtime: .off, calendar: self.calendar)
        }
        #expect(!invite(date(5, 22), date(5, 9, 30)))
        #expect(invite(date(5, 22), date(4, 9, 30)))
        // An invite just before the 05:00 day start still blocks one within 3 hours.
        #expect(!invite(date(6, 6), date(6, 4)))
        #expect(invite(date(6, 7), date(6, 4)))
    }

    @Test func celebratesLongRunsAndBoxingOnce() throws {
        let run = workout(.running, date(5, 7), minutes: 30, meters: 5200)
        let short = workout(.running, date(5, 8), minutes: 20, meters: 3000)
        let boxing = workout(.boxing, date(5, 9), minutes: 40)
        let walk = workout(.other, date(5, 10), minutes: 60)
        let all = [run, short, boxing, walk]

        #expect(NeedEngine.celebration(all, celebrated: [], now: date(5, 10)) == boxing)
        #expect(NeedEngine.celebration(all, celebrated: [boxing.id], now: date(5, 10)) == run)
        #expect(NeedEngine.celebration(all, celebrated: [boxing.id, run.id], now: date(5, 10)) == nil)
        #expect(NeedEngine.celebration([run], celebrated: [], now: date(5, 10, 31)) == nil)
        #expect(NeedEngine.celebration([run], celebrated: [], now: date(5, 7, 15)) == nil)
        let shortBoxing = workout(.boxing, date(5, 9), minutes: 20)
        #expect(NeedEngine.celebration([shortBoxing], celebrated: [], now: date(5, 10)) == nil)
    }

    @Test func whyLinePrefersBedtimeThenNeedThenEnergy() {
        let couch = NeedReading(need: .couchScroll, since: date(5, 20), reasons: ["刷够久了"])
        let energy = EnergyReading(level: .low, reasons: ["睡少了"], source: .sleep)
        #expect(NeedEngine.whyLine(need: couch, energy: energy, bedtime: .on) == "到点了，我先困了")
        #expect(NeedEngine.whyLine(need: couch, energy: energy, bedtime: .off) == "刷够久了")
        #expect(NeedEngine.whyLine(need: nil, energy: energy, bedtime: .off) == "睡少了")
        #expect(NeedEngine.whyLine(need: nil, energy: nil, bedtime: .off) == nil)
    }

    @Test func standardRulesRoundTrip() throws {
        let data = try JSONEncoder().encode(NeedRules.standard)
        #expect(try JSONDecoder().decode(NeedRules.self, from: data) == .standard)
        let sample = workout(.running, date(5, 7), minutes: 30, meters: 5000)
        let encoded = try JSONEncoder().encode(sample)
        #expect(try JSONDecoder().decode(WorkoutSummary.self, from: encoded) == sample)
    }

    @Test func snapshotCarriesNeedAndLine() throws {
        let now = date(5, 20)
        let snapshot = WidgetSnapshot(mode: .chill, since: nil, need: .couchScroll, line: "累了", updatedAt: now)
        let data = try HubJSON.encoder().encode(snapshot)
        let decoded = try HubJSON.decoder().decode(WidgetSnapshot.self, from: data)
        #expect(decoded.need == .couchScroll)
        #expect(decoded.line == "累了")
    }

    @Test func switchReplayShowsTheModeBeforeAnAutomaticChange() {
        let log = ModeLog(changes: [
            ModeChange(mode: .chill, source: .manual, at: date(5, 8), deviceID: "test"),
            ModeChange(mode: .work, source: .schedule, at: date(5, 9, 30), deviceID: "test"),
        ])
        #expect(log.switchedFrom(since: date(5, 9)) == .chill)
        #expect(log.switchedFrom(since: date(5, 10)) == nil)
        #expect(log.switchedFrom(since: date(5, 7)) == nil)

        var manual = log
        manual.changes.append(ModeChange(mode: .money, source: .manual, at: date(5, 11), deviceID: "test"))
        #expect(manual.switchedFrom(since: date(5, 9)) == nil)
    }
}
