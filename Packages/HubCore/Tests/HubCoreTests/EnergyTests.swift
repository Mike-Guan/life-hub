import Foundation
import Testing

@testable import HubCore

@Suite struct EnergyTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    @Test func sleepThresholdsPickTheLevel() {
        let thresholds = SleepThresholds.standard
        #expect(thresholds.level(forSleep: 5 * 60 + 59) == .low)
        #expect(thresholds.level(forSleep: 6 * 60) == .okay)
        #expect(thresholds.level(forSleep: 7 * 60 + 29) == .okay)
        #expect(thresholds.level(forSleep: 7 * 60 + 30) == .full)
    }

    @Test func levelsHaveDistinctLabelsAndRisingValues() {
        let levels = EnergyLevel.allCases
        #expect(Set(levels.map(\.title)).count == levels.count)
        #expect(levels.map(\.value) == levels.map(\.value).sorted())
    }

    @Test func noEventsMeansUnknown() {
        #expect(StateEngine.energy(events: [], now: date(3, 12), calendar: calendar) == nil)
    }

    @Test func sleepThatEndedTodaySetsEnergy() throws {
        let sleep = EnergyEvent.sleep(minutes: 5 * 60 + 40, endedAt: date(3, 7), deviceID: "test")
        let reading = try #require(StateEngine.energy(events: [sleep], now: date(3, 12), calendar: calendar))
        #expect(reading.level == .low)
        #expect(reading.source == .sleep)
        #expect(reading.reasons == ["昨晚睡了 5 小时 40 分，算「低电量」"])
        #expect(reading.value == EnergyLevel.low.value)
    }

    @Test func selfReportBeatsSleep() throws {
        let events = [
            EnergyEvent.selfReport(.full, at: date(3, 10), deviceID: "test"),
            EnergyEvent.sleep(minutes: 300, endedAt: date(3, 7), deviceID: "test"),
        ]
        let reading = try #require(StateEngine.energy(events: events, now: date(3, 12), calendar: calendar))
        #expect(reading.level == .full)
        #expect(reading.source == .selfReport)
    }

    @Test func latestSelfReportWins() throws {
        let events = [
            EnergyEvent.selfReport(.low, at: date(3, 15), deviceID: "test"),
            EnergyEvent.selfReport(.okay, at: date(3, 9), deviceID: "test"),
        ]
        let reading = try #require(StateEngine.energy(events: events, now: date(3, 16), calendar: calendar))
        #expect(reading.level == .low)
    }

    @Test func yesterdaysEventsAndFutureEventsDontCount() {
        let events = [
            EnergyEvent.selfReport(.full, at: date(2, 20), deviceID: "test"),
            EnergyEvent.selfReport(.low, at: date(3, 18), deviceID: "test"),
        ]
        #expect(StateEngine.energy(events: events, now: date(3, 12), calendar: calendar) == nil)
    }

    @Test func dayStartsAtFive() {
        #expect(StateEngine.dayStart(for: date(3, 4, 59), calendar: calendar) == date(2, 5))
        #expect(StateEngine.dayStart(for: date(3, 5), calendar: calendar) == date(3, 5))
        let lateReport = EnergyEvent.selfReport(.low, at: date(3, 1), deviceID: "test")
        #expect(StateEngine.energy(events: [lateReport], now: date(3, 2), calendar: calendar)?.level == .low)
        #expect(StateEngine.energy(events: [lateReport], now: date(3, 9), calendar: calendar) == nil)
    }

    @Test func deletedEventsAreIgnored() {
        var report = EnergyEvent.selfReport(.full, at: date(3, 9), deviceID: "test")
        report.deletedAt = date(3, 10)
        #expect(StateEngine.energy(events: [report], now: date(3, 12), calendar: calendar) == nil)
    }

    @Test func decodesMinimalEventWithDefaults() throws {
        let json = #"{"id":"6F1C2B1E-2D7A-4C1A-9E43-1B2C3D4E5F60","kind":"sleep","at":"2026-10-03T07:00:00Z"}"#
        let event = try HubJSON.decoder().decode(EnergyEvent.self, from: Data(json.utf8))
        #expect(event.kind == .sleep)
        #expect(event.schemaVersion == 1)
        #expect(event.sleepMinutes == nil)
        #expect(event.createdAt == event.at)
        #expect(event.updatedBy == "unknown")
    }

    @Test func logKeepsUnreadableEventsThroughASave() throws {
        let json = #"""
            {"schemaVersion":1,"events":[
              {"id":"6F1C2B1E-2D7A-4C1A-9E43-1B2C3D4E5F60","kind":"selfReport","level":"okay","at":"2026-10-03T07:00:00Z"},
              {"id":"7F1C2B1E-2D7A-4C1A-9E43-1B2C3D4E5F60","kind":"heartRate","at":"2026-10-03T08:00:00Z"}
            ]}
            """#
        let log = try HubJSON.decoder().decode(EnergyLog.self, from: Data(json.utf8))
        #expect(log.events.count == 1)
        #expect(log.unreadable.count == 1)
        let again = try HubJSON.decoder().decode(EnergyLog.self, from: HubJSON.encoder().encode(log))
        #expect(again.events == log.events)
        #expect(again.unreadable == log.unreadable)
    }

    @Test func mergeAddsOnlyMissingRecords() {
        let first = EnergyEvent.selfReport(.low, at: date(3, 9), deviceID: "a")
        let second = EnergyEvent.selfReport(.full, at: date(3, 10), deviceID: "b")
        let merged = EnergyLog(events: [first]).merged(with: EnergyLog(events: [first, second]))
        #expect(merged.events.map(\.id) == [first.id, second.id])
    }

    @MainActor @Test func storeRecordsOnceAndPersists() {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "lifehub-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "energy-log.json")
        let store = EnergyStore(fileURL: url, deviceID: "test")
        let event = EnergyEvent.sleep(minutes: 480, endedAt: date(3, 7), deviceID: "test")
        #expect(store.record(event))
        #expect(!store.record(event))
        store.report(.okay, at: date(3, 9))
        #expect(store.lastError == nil)

        let reloaded = EnergyStore(fileURL: url, deviceID: "test")
        #expect(reloaded.log.events.count == 2)
        #expect(reloaded.reading(now: date(3, 12), calendar: calendar)?.level == .okay)
    }
}

@Suite struct BedtimeTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func time(_ hour: Int, _ minute: Int) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: 3, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    @Test func standardWindowCrossesMidnight() {
        let schedule = BedtimeSchedule.standard
        #expect(schedule.state(at: time(23, 29), calendar: calendar) == .off)
        #expect(schedule.state(at: time(23, 30), calendar: calendar) == .on)
        #expect(schedule.state(at: time(2, 0), calendar: calendar) == .on)
        #expect(schedule.state(at: time(4, 59), calendar: calendar) == .on)
        #expect(schedule.state(at: time(5, 0), calendar: calendar) == .off)
        #expect(schedule.state(at: time(12, 0), calendar: calendar) == .off)
    }

    @Test func windowWithinOneDay() {
        let nap = BedtimeSchedule(startMinute: 13 * 60, endMinute: 14 * 60)
        #expect(nap.state(at: time(13, 30), calendar: calendar) == .on)
        #expect(nap.state(at: time(14, 0), calendar: calendar) == .off)
    }

    @Test func snapshotCarriesEnergyAndBedtime() throws {
        let snapshot = WidgetSnapshot(log: ModeLog(), energy: .okay, bedtime: .on, now: time(23, 40))
        let decoded = try HubJSON.decoder().decode(WidgetSnapshot.self, from: HubJSON.encoder().encode(snapshot))
        #expect(decoded == snapshot)
        let old = #"{"schemaVersion":1,"mode":"work","updatedAt":"2026-10-03T07:00:00Z"}"#
        let fromOldBuild = try HubJSON.decoder().decode(WidgetSnapshot.self, from: Data(old.utf8))
        #expect(fromOldBuild.energy == nil)
        #expect(fromOldBuild.bedtime == nil)
    }
}
