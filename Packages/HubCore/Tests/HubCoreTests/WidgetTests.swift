import Foundation
import Testing

@testable import HubCore

@MainActor
@Suite struct WidgetTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    func tempContainer() -> HubContainer {
        let folder = FileManager.default.temporaryDirectory.appending(path: "lifehub-tests-\(UUID().uuidString)")
        return HubContainer(folder: folder)
    }

    @Test func inboxDrainsOldestFirstAndDeletesAccepted() throws {
        let inbox = tempContainer().inbox
        let late = ModeChange(mode: .chill, at: date(3, 19), deviceID: "widget")
        let early = ModeChange(mode: .work, at: date(3, 10), deviceID: "widget")
        try inbox.post(.mode(late))
        try inbox.post(.mode(early))

        var seen: [Mode] = []
        let accepted = inbox.drain { item in
            if case .mode(let change) = item { seen.append(change.mode) }
            return true
        }
        #expect(accepted == 2)
        #expect(seen == [.work, .chill])
        #expect(inbox.drain { _ in true } == 0)
    }

    @Test func rejectedAndUnreadableItemsStay() throws {
        let inbox = tempContainer().inbox
        let folder = try #require(inbox.folder)
        try inbox.post(.energy(.selfReport(.low, at: date(3, 9), deviceID: "widget")))
        try Data("not json".utf8).write(to: folder.appending(path: "broken.json"))

        #expect(inbox.drain { _ in false } == 0)
        #expect(inbox.drain { _ in true } == 1)
        let left = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(left == ["broken.json"])
    }

    @Test func inMemoryInboxDoesNothing() throws {
        let inbox = EventInbox(folder: nil)
        try inbox.post(.mode(ModeChange(mode: .work, deviceID: "widget")))
        #expect(inbox.drain { _ in true } == 0)
    }

    @Test func syncAppliesWidgetChangesOnceAndWritesSnapshot() throws {
        let container = tempContainer()
        let modes = ModeStore(fileURL: container.modeLogURL, deviceID: "iphone")
        let energy = EnergyStore(fileURL: container.energyLogURL, deviceID: "iphone")
        let bridge = WidgetBridge(container: container)
        let change = ModeChange(mode: .boxing, at: date(3, 19), deviceID: "widget")
        try container.inbox.post(.mode(change))
        try container.inbox.post(.mode(change))
        try container.inbox.post(.energy(.selfReport(.full, at: date(3, 19, 5), deviceID: "widget")))

        #expect(bridge.sync(mode: modes, energy: energy, now: date(3, 20), calendar: calendar) == 2)
        #expect(modes.current == .boxing)
        #expect(modes.log.changes.count == 1)
        #expect(energy.log.events.count == 1)

        let url = try #require(container.snapshotURL)
        let snapshot = try #require(WidgetSnapshot.read(from: url))
        #expect(snapshot.mode == .boxing)
        #expect(snapshot.energy == .full)
        #expect(snapshot.bedtime == .off)
        #expect(snapshot.line == HakuLines.line(.boxing, at: date(3, 20), calendar: calendar))
        #expect(snapshot.need == nil)
        #expect(bridge.lastError == nil)

        bridge.need = NeedReading(need: .couchScroll, since: date(3, 19), reasons: ["瘫着"])
        bridge.writeSnapshot(mode: modes, energy: energy, now: date(3, 20), calendar: calendar)
        #expect(WidgetSnapshot.read(from: url)?.need == .couchScroll)
        let scrolling = HakuLines.line(.couchScroll, at: date(3, 20), calendar: calendar)
        #expect(WidgetSnapshot.read(from: url)?.line == scrolling)
        let lifted = WorkoutSummary(id: "lift-7f3a", kind: .strength, start: date(3, 18, 7), end: date(3, 19, 13))
        bridge.workouts = [lifted]
        bridge.writeSnapshot(mode: modes, energy: energy, now: date(3, 20), calendar: calendar)
        let written = try #require(WidgetSnapshot.read(from: url))
        #expect(written.trainedDay == StateEngine.dayStart(for: date(3, 19), calendar: calendar))
        #expect(written.ranDay == nil)
        // Only the day goes into the App Group: no HealthKit id or workout times.
        let json = try String(contentsOf: url, encoding: .utf8)
        #expect(!json.contains("lift-7f3a"))
        let encoded = try HubJSON.encoder().encode([lifted.start, lifted.end])
        let times = try JSONDecoder().decode([String].self, from: encoded)
        #expect(times.allSatisfy { !json.contains($0) })

        container.inbox.drain { _ in false }
        try container.inbox.post(.mode(change))
        #expect(bridge.sync(mode: modes, energy: energy, now: date(3, 23, 45), calendar: calendar) == 1)
        #expect(modes.log.changes.count == 1)
        #expect(WidgetSnapshot.read(from: url)?.bedtime == .on)
    }

    @Test func syncAppliesPaymentsOnlyWithAnExpenseStore() throws {
        let container = tempContainer()
        let modes = ModeStore(fileURL: container.modeLogURL, deviceID: "iphone")
        let energy = EnergyStore(fileURL: container.energyLogURL, deviceID: "iphone")
        let bridge = WidgetBridge(container: container)
        let payment = Expense(amount: 900, category: .diningOut, day: date(3, 0), deviceID: "pay", now: date(3, 12))
        try container.inbox.post(.expense(payment))
        #expect(InboxItem.expense(payment).at == date(3, 12))

        #expect(bridge.sync(mode: modes, energy: energy, now: date(3, 13), calendar: calendar) == 0)
        let expenses = ExpenseStore(fileURL: container.expenseLogURL, deviceID: "iphone")
        let applied = bridge.sync(mode: modes, energy: energy, expenses: expenses, now: date(3, 13), calendar: calendar)
        #expect(applied == 1)
        #expect(expenses.log.expenses == [payment])
        #expect(!expenses.record(payment))

        let reloaded = ExpenseStore(fileURL: container.expenseLogURL, deviceID: "iphone")
        #expect(reloaded.log.expenses == [payment])
        #expect(reloaded.lastError == nil)
    }

    @Test func snapshotWriteFailureIsReported() throws {
        let container = tempContainer()
        let folder = try #require(container.folder)
        // A file where the folder should be makes the write fail.
        try Data().write(to: folder)
        let bridge = WidgetBridge(container: container)
        bridge.writeSnapshot(
            mode: ModeStore(fileURL: nil, deviceID: "t"),
            energy: EnergyStore(fileURL: nil, deviceID: "t")
        )
        #expect(bridge.lastError != nil)
    }

    @Test func postUpdatesAnExistingSnapshot() throws {
        let container = tempContainer()
        let url = try #require(container.snapshotURL)
        let at = date(3, 9)

        // No snapshot yet: the change waits in the inbox only.
        try container.post(.mode(ModeChange(mode: .work, at: at, deviceID: "widget")))
        #expect(WidgetSnapshot.read(from: url) == nil)

        try WidgetSnapshot(mode: .work, since: at, updatedAt: at).write(to: url)
        try container.post(.mode(ModeChange(mode: .money, at: date(3, 21), deviceID: "widget")))
        try container.post(.energy(.selfReport(.low, at: date(3, 21, 1), deviceID: "widget")))
        let snapshot = try #require(WidgetSnapshot.read(from: url))
        #expect(snapshot.mode == .money)
        #expect(snapshot.since == date(3, 21))
        #expect(snapshot.energy == .low)
        #expect(snapshot.updatedAt == date(3, 21, 1))
        #expect(container.inbox.drain { _ in true } == 3)
    }

    @Test func applyingKeepsSinceForTheSameModeAndIgnoresSleep() {
        let at = date(3, 9)
        let snapshot = WidgetSnapshot(mode: .work, since: at, energy: .okay, updatedAt: at)
        let same = snapshot.applying(.mode(ModeChange(mode: .work, at: date(3, 10), deviceID: "w")))
        #expect(same.since == at)
        let sleep = snapshot.applying(.energy(.sleep(minutes: 300, endedAt: date(3, 7), deviceID: "w")))
        #expect(sleep.energy == .okay)
        #expect(sleep.updatedAt == at)
    }

    @Test func energyExpiresAtTheNextDayStart() {
        let snapshot = WidgetSnapshot(mode: .work, since: nil, energy: .full, updatedAt: date(3, 22))
        #expect(snapshot.energy(at: date(4, 4, 59), calendar: calendar) == .full)
        #expect(snapshot.energy(at: date(4, 5), calendar: calendar) == nil)
    }

    @Test func timelineRedrawsAtBedtimeAndDayStart() {
        let dates = WidgetSnapshot.timelineDates(after: date(3, 20), bedtime: .standard, calendar: calendar)
        #expect(dates == [date(3, 20), date(3, 23, 30), date(4, 5)])
        let night = WidgetSnapshot.timelineDates(after: date(4, 1), bedtime: .standard, calendar: calendar)
        #expect(night == [date(4, 1), date(4, 5)])
    }

    @Test func bedtimeNextChange() {
        let schedule = BedtimeSchedule.standard
        #expect(schedule.nextChange(after: date(3, 12), calendar: calendar) == date(3, 23, 30))
        #expect(schedule.nextChange(after: date(3, 23, 30), calendar: calendar) == date(4, 5))
    }

    @Test func adoptsOldLogsOnce() throws {
        let old = tempContainer()
        let new = tempContainer()
        let oldStore = ModeStore(fileURL: old.modeLogURL, deviceID: "iphone")
        oldStore.switchTo(.chill)

        #expect(new.adoptLogs(from: old).isEmpty)
        #expect(ModeStore(fileURL: new.modeLogURL, deviceID: "iphone").current == .chill)

        ModeStore(fileURL: old.modeLogURL, deviceID: "iphone").switchTo(.work)
        #expect(new.adoptLogs(from: old).isEmpty)
        #expect(ModeStore(fileURL: new.modeLogURL, deviceID: "iphone").current == .chill)
    }

    @Test func applyIsIdempotentAndKeepsTheConfirmRule() {
        let store = ModeStore(fileURL: nil, deviceID: "iphone")
        let auto = ModeChange(mode: .work, source: .schedule, at: date(3, 9), deviceID: "iphone")
        #expect(store.apply(auto))
        #expect(!store.apply(auto))
        #expect(!store.apply(ModeChange(mode: .work, source: .calendar, at: date(3, 10), deviceID: "w")))
        #expect(store.apply(ModeChange(mode: .work, at: date(3, 11), deviceID: "w")))
    }

    @Test func deviceIDIsStable() throws {
        let suite = "lifehub-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(HubDevice.id(defaults: defaults) == HubDevice.id(defaults: defaults))
    }

    @Test func liveStoresUseTheContainer() {
        let container = tempContainer()
        let suite = "lifehub-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defer { defaults.removePersistentDomain(forName: suite) }
        let modes = ModeStore.live(in: container, defaults: defaults)
        let energy = EnergyStore.live(in: container, defaults: defaults)
        #expect(modes.deviceID == energy.deviceID)
        modes.switchTo(.money)
        #expect(ModeStore(fileURL: container.modeLogURL, deviceID: "x").current == .money)
    }
}
