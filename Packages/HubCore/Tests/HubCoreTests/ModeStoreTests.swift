import Foundation
import Testing

@testable import HubCore

@MainActor
@Suite struct ModeStoreTests {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "lifehub-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "mode-log.json")
    }

    @Test func switchingToSameModeIsANoOp() {
        let store = ModeStore(fileURL: nil, deviceID: "test")
        #expect(store.current == nil)
        #expect(store.switchTo(.work))
        #expect(!store.switchTo(.work))
        #expect(store.log.changes.count == 1)
        #expect(store.log.changes[0].updatedBy == "test")
    }

    @Test func persistsAndReloads() {
        let url = tempURL()
        let store = ModeStore(fileURL: url, deviceID: "test")
        store.switchTo(.work, source: .schedule)
        store.switchTo(.boxing, source: .location)
        #expect(store.lastError == nil)

        let reloaded = ModeStore(fileURL: url, deviceID: "test")
        #expect(reloaded.current == .boxing)
        #expect(reloaded.log.changes.map(\.source) == [.schedule, .location])
    }

    @Test func corruptFileIsReportedNotSwallowed() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        let store = ModeStore(fileURL: url, deviceID: "test")
        #expect(store.lastError != nil)
        #expect(store.current == nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        let backups = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
        #expect(backups.contains { $0.hasPrefix("mode-log.corrupt-") })
    }

    @Test func manualTapConfirmsAnAutomaticMode() {
        let store = ModeStore(fileURL: nil, deviceID: "test")
        store.switchTo(.work, source: .schedule)
        #expect(!store.switchTo(.work, source: .location))
        #expect(store.switchTo(.work))
        #expect(store.log.current?.source == .manual)
        #expect(!store.switchTo(.work))
        #expect(store.log.changes.count == 2)
    }

    @Test func unreadableFileIsNotMovedOrOverwritten() throws {
        let url = tempURL()
        // A directory at the file's path can't be read as data, like a protected file before unlock.
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let store = ModeStore(fileURL: url, deviceID: "test")
        #expect(store.lastError != nil)
        let at = Date(timeIntervalSince1970: 1_790_000_000)
        store.switchTo(.chill, at: at)
        #expect(store.lastError != nil)
        let siblings = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
        #expect(siblings == ["mode-log.json"])

        try FileManager.default.removeItem(at: url)
        store.switchTo(.work, at: at.addingTimeInterval(600))
        #expect(store.lastError == nil)
        let reloaded = ModeStore(fileURL: url, deviceID: "test")
        #expect(reloaded.log.changes.map(\.mode) == [.chill, .work])
    }

    @Test func quickManualSwitchCorrectsTheLastOne() {
        let store = ModeStore(fileURL: nil, deviceID: "test")
        let at = Date(timeIntervalSince1970: 1_790_000_000)
        store.switchTo(.work, source: .schedule, at: at)
        store.switchTo(.boxing, at: at.addingTimeInterval(600))

        // A mistap replaced within the window: only the new mode stays.
        #expect(store.switchTo(.chill, at: at.addingTimeInterval(660)))
        #expect(store.log.active.map(\.mode) == [.work, .chill])
        #expect(store.log.changes.count == 3)
        #expect(store.log.changes[1].deletedAt == at.addingTimeInterval(660))

        // Switching back to the mode before undoes the tap; the automatic one is current again.
        // The undo adds nothing, so the app watches the current change, not the count.
        let corrected = store.log.current?.id
        #expect(store.switchTo(.work, at: at.addingTimeInterval(700)))
        #expect(store.log.active.map(\.mode) == [.work])
        #expect(store.log.current?.source == .schedule)
        #expect(store.log.changes.count == 3)
        #expect(store.log.current?.id != corrected)

        // After the window a switch is kept.
        store.switchTo(.money, at: at.addingTimeInterval(800))
        store.switchTo(.chill, at: at.addingTimeInterval(800 + ModeStore.correctionWindow))
        #expect(store.log.active.map(\.mode) == [.work, .money, .chill])
    }

    @Test func snapshotFollowsCurrentMode() {
        let store = ModeStore(fileURL: nil, deviceID: "test")
        let at = Date(timeIntervalSince1970: 1_790_000_000)
        store.switchTo(.money, at: at)
        let snapshot = store.snapshot(now: at.addingTimeInterval(60))
        #expect(snapshot.mode == .money)
        #expect(snapshot.since == at)
    }
}
