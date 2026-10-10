import Foundation
import Testing

@testable import HubCore

@Suite struct MemoryTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func date(_ day: Int, _ hour: Int = 18) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour)) ?? .distantPast
    }

    func wins(_ win: Win, _ days: [Int]) -> [CanEntry] {
        days.map { CanEntry.earned(win, source: "\($0)", at: date($0), deviceID: "t") }
    }

    func habits(_ ledger: CanLedger, persona: Persona = .haku, resets: MemoryResets = .init()) -> [LearnedHabit] {
        Memory.habits(
            persona: persona,
            days: .standard,
            ledger: ledger,
            resets: resets,
            now: date(20),
            calendar: calendar
        )
    }

    @Test func aResetCountsFromTheLaterForget() {
        let resets = MemoryResets(all: date(5), habits: [.gymDays: date(9)])
        #expect(resets.since(.gymDays) == date(9))
        #expect(resets.since(.identityDay) == date(5))
        #expect(MemoryResets().since(.gymDays) == nil)
    }

    @Test func resetsAreStored() throws {
        let defaults = try #require(UserDefaults(suiteName: "memory-\(UUID().uuidString)"))
        let resets = MemoryResets(all: date(5), habits: [.identityDay: date(9)])
        resets.store(in: defaults)
        #expect(MemoryResets.stored(in: defaults) == resets)
    }

    @Test func aLedgerSinceDropsOlderEntries() {
        let ledger = CanLedger(entries: wins(.gym, [6, 8, 13]))
        #expect(ledger.since(date(8)).entries.count == 2)
        #expect(ledger.since(nil) == ledger)
    }

    @Test func gymDaysAreLearnedAndForgotten() {
        // Tuesdays and Thursdays in two weeks.
        let ledger = CanLedger(entries: wins(.gym, [6, 8, 13, 15]))
        let learned = habits(ledger)
        #expect(learned == [LearnedHabit(habit: .gymDays, title: "健身日", days: "周二、周四", isLearned: true)])
        let forgotten = habits(ledger, resets: MemoryResets(habits: [.gymDays: date(16)]))
        #expect(forgotten.first?.days == "周二、周三、周四")
        #expect(forgotten.first?.isLearned == false)
    }

    @Test func kuroAlsoLearnsHerIdentityDay() {
        let ledger = CanLedger(entries: wins(.boxing, [3, 10]))
        let list = habits(ledger, persona: .kuro)
        #expect(list.map(\.habit) == [.gymDays, .identityDay])
        #expect(list.last == LearnedHabit(habit: .identityDay, title: "网球日", days: "周六", isLearned: true))
        let forgotten = habits(ledger, persona: .kuro, resets: MemoryResets(all: date(11)))
        #expect(forgotten.last?.isLearned == false)
    }

    @Test func longTermMemoriesComeFromRecordsAfterTheLastForget() {
        let changes = [
            ModeChange(mode: .work, source: .location, at: date(5, 9), deviceID: "t"),
            ModeChange(mode: .boxing, source: .location, at: date(4, 10), deviceID: "t"),
            ModeChange(mode: .work, source: .location, at: date(6, 9), deviceID: "t"),
            ModeChange(mode: .work, source: .location, at: date(7, 9), deviceID: "t"),
            ModeChange(mode: .chill, source: .manual, at: date(7, 18), deviceID: "t"),
        ]
        let ledger = CanLedger(entries: wins(.run5k, [3]) + wins(.gym, [6, 8]))
        let places = [
            HubPlace(kind: .office, latitude: 0, longitude: 0),
            HubPlace(kind: .gym, latitude: 0, longitude: 0),
            HubPlace(kind: .home, latitude: 0, longitude: 0),
        ]
        let list = Memory.longTerm(
            persona: .haku,
            changes: changes,
            ledger: ledger,
            places: places,
            resets: MemoryResets()
        )
        #expect(
            list == [
                LongMemory(title: "第一次拳击日", date: date(4, 10)),
                LongMemory(title: "第一次去健身房", date: date(6)),
                LongMemory(title: "第一次跑完 5 公里", date: date(3)),
                LongMemory(title: "常待的地方", detail: "公司"),
            ]
        )
        let after = Memory.longTerm(
            persona: .kuro,
            changes: changes,
            ledger: ledger,
            places: places,
            resets: MemoryResets(all: date(5, 0))
        )
        #expect(
            after == [LongMemory(title: "第一次去健身房", date: date(6)), LongMemory(title: "常待的地方", detail: "公司")]
        )
    }

    @Test func deletedChangesAreNotRemembered() {
        var boxing = ModeChange(mode: .boxing, at: date(4, 10), deviceID: "t")
        boxing.deletedAt = date(5)
        let list = Memory.longTerm(
            persona: .haku,
            changes: [boxing],
            ledger: CanLedger(),
            places: [],
            resets: MemoryResets()
        )
        #expect(list.isEmpty)
    }

    @Test func forgettingAllMomentsKeepsThemMarked() {
        var log = ChangeLog(moments: [
            ChangeMoment(kind: .gotUp, source: "a", at: date(3), deviceID: "t"),
            ChangeMoment(kind: .nearUnlock, source: "b", at: date(4), deviceID: "t"),
        ])
        let counts = [log.forgetAll(at: date(5), by: "phone"), log.forgetAll(at: date(6), by: "phone")]
        #expect(counts == [2, 0])
        #expect(log.moments.map(\.deletedAt) == [date(5), date(5)])
        #expect(log.moments.allSatisfy { $0.updatedBy == "phone" })
        // A moment noted again from the same source stays deleted.
        let added = log.record(ChangeMoment(kind: .gotUp, source: "a", at: date(3), deviceID: "t"))
        #expect(!added)
    }

    @Test func weekdaysStartOnMonday() {
        #expect(Memory.weekdays([1, 3, 5]) == "周二、周四、周日")
        #expect(Memory.weekdays([]) == "")
    }

    @Test func onlyPlacesThatSwitchAModeCount() {
        #expect(Memory.mode(for: .work) == .work)
        #expect(Memory.mode(for: .sideHustle) == .money)
        #expect(Memory.mode(for: .boxing) == .boxing)
        #expect(Memory.mode(for: .chill) == .chill)
        #expect(Memory.mode(for: .fitness) == nil)
        #expect(Memory.mode(for: .recordOnly) == nil)
    }
}
