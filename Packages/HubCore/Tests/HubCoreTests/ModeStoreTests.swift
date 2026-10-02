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

    @Test func snapshotFollowsCurrentMode() {
        let store = ModeStore(fileURL: nil, deviceID: "test")
        let at = Date(timeIntervalSince1970: 1_790_000_000)
        store.switchTo(.money, at: at)
        let snapshot = store.snapshot(now: at.addingTimeInterval(60))
        #expect(snapshot.mode == .money)
        #expect(snapshot.since == at)
    }
}
