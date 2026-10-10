import Foundation
import Testing

@testable import HubCore

// Issue #237: 删除全部数据 in Settings.
@MainActor
@Suite struct EraseTests {
    func tempContainer() -> HubContainer {
        HubContainer(
            folder: FileManager.default.temporaryDirectory
                .appending(path: "lifehub-erase-\(UUID().uuidString)", directoryHint: .isDirectory)
        )
    }

    func exists(_ url: URL?) -> Bool {
        url.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }

    @Test func storesEraseTheirRecordsAndFiles() {
        let container = tempContainer()
        let modes = ModeStore(fileURL: container.modeLogURL, deviceID: "t")
        let energy = EnergyStore(fileURL: container.energyLogURL, deviceID: "t")
        let expenses = ExpenseStore(fileURL: container.expenseLogURL, deviceID: "t")
        let growth = GrowthStore(fileURL: container.canLedgerURL, deviceID: "t")
        modes.switchTo(.work)
        energy.report(.low)
        expenses.record(Expense(amount: 500, category: .other, day: .now, deviceID: "t", now: .now))
        growth.record(.gym, source: "a")
        #expect(exists(container.modeLogURL) && exists(container.canLedgerURL))
        let revision = modes.revision

        modes.eraseAll()
        energy.eraseAll()
        expenses.eraseAll()
        growth.eraseAll()

        #expect(modes.log.changes.isEmpty && modes.revision == revision + 1)
        #expect(energy.log.records.isEmpty && expenses.log.records.isEmpty && growth.ledger.entries.isEmpty)
        let urls = [container.modeLogURL, container.energyLogURL, container.expenseLogURL, container.canLedgerURL]
        #expect(urls.allSatisfy { !exists($0) })
        #expect([modes.lastError, energy.lastError, expenses.lastError, growth.lastError].allSatisfy { $0 == nil })
        #expect(ModeStore(fileURL: container.modeLogURL, deviceID: "t").log.changes.isEmpty)
    }

    @Test func eraseFilesKeepsWhatIsNotTheHubs() throws {
        let container = tempContainer()
        let folder = try #require(container.folder)
        let files = FileManager.default
        try files.createDirectory(at: folder.appending(path: "inbox"), withIntermediateDirectories: true)
        try files.createDirectory(at: folder.appending(path: "Library"), withIntermediateDirectories: true)
        for name in ["decision-log.json", "mode-log.corrupt-1.json", "inbox/a.json", "Library/prefs.plist"] {
            try Data("{}".utf8).write(to: folder.appending(path: name))
        }
        #expect(container.eraseFiles().isEmpty)
        #expect(try files.contentsOfDirectory(atPath: folder.path) == ["Library"])
        #expect(HubContainer(folder: nil).eraseFiles().isEmpty)
    }

    @Test func eraseDefaultsKeepsTheDeviceID() throws {
        let defaults = try #require(UserDefaults(suiteName: "erase-\(UUID().uuidString)"))
        let id = HubDevice.id(defaults: defaults)
        defaults.set(true, forKey: "anything")
        HubDevice.eraseDefaults(defaults)
        #expect(defaults.object(forKey: "anything") == nil)
        #expect(HubDevice.id(defaults: defaults) == id)
    }
}
