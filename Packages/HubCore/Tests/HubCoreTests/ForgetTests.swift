import Foundation
import Testing

@testable import HubCore

@MainActor
@Suite struct ForgetTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    func change(_ mode: Mode, _ at: Date) -> ModeChange {
        ModeChange(mode: mode, source: .location, at: at, deviceID: "test")
    }

    @Test func forgettingOneKeepsTheRecordMarked() {
        let work = change(.work, date(3, 9))
        let chill = change(.chill, date(3, 18))
        var log = ModeLog(changes: [work, chill])
        #expect(log.forget(at: date(3, 20), by: "phone") { $0.id == chill.id } == 1)
        #expect(log.records.count == 2)
        #expect(log.kept.map(\.id) == [work.id])
        #expect(log.current?.id == work.id)
        let deleted = log.records.first { $0.id == chill.id }
        #expect(deleted?.deletedAt == date(3, 20))
        #expect(deleted?.updatedBy == "phone")
    }

    @Test func forgettingAllKeepsTheFirstDelete() {
        var log = ModeLog(changes: [change(.work, date(3, 9)), change(.chill, date(3, 18))])
        log.forget(at: date(3, 19), by: "phone") { $0.mode == .work }
        #expect(log.forget(at: date(3, 20), by: "phone") { _ in true } == 1)
        #expect(log.kept.isEmpty)
        #expect(log.records.map(\.deletedAt) == [date(3, 19), date(3, 20)])
    }

    @Test func aDayStartsAtFive() {
        let day = MemoryDay(containing: date(3, 12), calendar: calendar)
        #expect(day.contains(date(3, 6)))
        #expect(day.contains(date(4, 4, 59)))
        #expect(!day.contains(date(3, 4)))
        #expect(!day.contains(date(4, 5)))
        var log = ModeLog(changes: [change(.chill, date(3, 1)), change(.work, date(3, 9)), change(.chill, date(4, 9))])
        #expect(log.forget(at: date(4, 10), by: "phone") { day.contains($0.at) } == 1)
        #expect(log.kept.map(\.mode) == [.chill, .chill])
    }

    @Test func anOlderReaderKeepsItDeleted() throws {
        var log = ModeLog(changes: [change(.work, date(3, 9))])
        log.forget(at: date(3, 20), by: "phone") { _ in true }
        let data = try HubJSON.encoder().encode(log)
        let read = try HubJSON.decoder().decode(ModeLog.self, from: data)
        #expect(read.active.isEmpty)
        #expect(read.records.first?.deletedAt == date(3, 20))
    }

    @Test func summaryCountsOnlyKeptRecords() {
        var log = DecisionLog(decisions: [
            Decision(kind: .push, action: "none", at: date(3, 9), deviceID: "test"),
            Decision(kind: .push, action: "none", at: date(5, 9), deviceID: "test"),
            Decision(kind: .push, action: "none", at: date(7, 9), deviceID: "test"),
        ])
        log.forget(at: date(8, 9), by: "phone") { $0.at == date(7, 9) }
        #expect(log.summary == MemorySummary(count: 2, first: date(3, 9), last: date(5, 9)))
        #expect(DecisionLog().summary == MemorySummary(count: 0, first: nil, last: nil))
    }

    @Test func storeForgetMovesTheCurrentModeBack() {
        let store = ModeStore(fileURL: nil, deviceID: "phone")
        store.apply(change(.work, date(3, 9)))
        store.apply(change(.chill, date(3, 18)))
        let before = store.revision
        #expect(store.forget(at: date(3, 20)) { $0.mode == .chill } == 1)
        #expect(store.current == .work)
        #expect(store.revision == before + 1)
        #expect(store.forget(at: date(3, 21)) { $0.mode == .chill } == 0)
        #expect(store.revision == before + 1)
    }

    @Test func aDeletedNightStaysDeletedWhenImportedAgain() {
        let energy = EnergyStore(fileURL: nil, deviceID: "phone")
        let id = UUID()
        energy.record(SleepNight(id: id, minutes: 5 * 60, endedAt: date(3, 7)), now: date(3, 8))
        #expect(energy.forget(at: date(3, 9)) { $0.kind == .sleep } == 1)
        #expect(energy.reading(now: date(3, 12), calendar: calendar) == nil)
        energy.record(SleepNight(id: id, minutes: 5 * 60 + 10, endedAt: date(3, 7)), now: date(3, 10))
        #expect(energy.reading(now: date(3, 12), calendar: calendar) == nil)
    }
}
