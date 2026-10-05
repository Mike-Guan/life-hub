import Foundation
import HubCore
import Observation

// PRD section 15, Mike 2026-10-05: both apps work alone; Life Hub links to Daily only when Mike turns it
// on in Settings. Daily's folder is read, never written.
/// Reads Daily Widget's tasks from the iCloud Drive folder Mike picked.
@MainActor
@Observable
final class DailyLink {
    /// Whether Mike linked a Daily folder.
    private(set) var isOn: Bool
    /// The tasks from the last read; empty while not linked.
    private(set) var tasks: [DailyTask] = []
    /// Last failure, for the UI to show.
    private(set) var lastError: String?

    private static let bookmarkKey = "dailyFolderBookmark"

    init() {
        isOn = AppGroup.defaults.data(forKey: Self.bookmarkKey) != nil
    }

    /// Links the folder Mike picked and reads it.
    /// - Parameter folder: Daily's folder, or its `tasks` folder.
    func link(_ folder: URL) async {
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        do {
            AppGroup.defaults.set(try Self.bookmark(for: folder), forKey: Self.bookmarkKey)
            isOn = true
            await read()
        } catch {
            lastError = "联动 Daily 失败：\(error.localizedDescription)"
        }
    }

    /// Unlinks: forgets the folder and the tasks read. Cans already earned stay.
    func unlink() {
        AppGroup.defaults.removeObject(forKey: Self.bookmarkKey)
        isOn = false
        tasks = []
        lastError = nil
    }

    /// Re-reads the linked folder; does nothing while not linked.
    func read() async {
        guard let bookmark = AppGroup.defaults.data(forKey: Self.bookmarkKey) else { return }
        var stale = false
        guard let folder = try? URL(resolvingBookmarkData: bookmark, options: [], bookmarkDataIsStale: &stale) else {
            lastError = "找不到 Daily 的文件夹了，请在设置里重新联动"
            return
        }
        let result = await Task.detached { Self.load(from: folder) }.value
        switch result {
        case .success(let read):
            tasks = read
            lastError = nil
        case .failure(let error):
            lastError = "读不到 Daily 的文件夹：\(error.localizedDescription)"
        }
        if stale, let fresh = try? Self.bookmark(for: folder) {
            AppGroup.defaults.set(fresh, forKey: Self.bookmarkKey)
        }
    }

    private static func bookmark(for folder: URL) throws -> Data {
        try folder.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    // One JSON per task in `tasks/`. Files iCloud hasn't downloaded yet are `.<name>.icloud`
    // placeholders: ask for the download and read them next time. Files that don't decode are skipped.
    private nonisolated static func load(from folder: URL) -> Result<[DailyTask], Error> {
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        let manager = FileManager.default
        let nested = folder.appending(path: "tasks", directoryHint: .isDirectory)
        let tasksFolder = manager.fileExists(atPath: nested.path(percentEncoded: false)) ? nested : folder
        var coordinationError: NSError?
        var result: Result<[DailyTask], Error> = .success([])
        NSFileCoordinator().coordinate(readingItemAt: tasksFolder, options: [], error: &coordinationError) { url in
            do {
                let names = try manager.contentsOfDirectory(atPath: url.path(percentEncoded: false))
                var tasks: [DailyTask] = []
                for name in names {
                    if name.hasPrefix("."), name.hasSuffix(".icloud") {
                        let real = String(name.dropFirst().dropLast(".icloud".count))
                        try? manager.startDownloadingUbiquitousItem(at: url.appending(path: real))
                    } else if name.hasSuffix(".json"), let data = try? Data(contentsOf: url.appending(path: name)) {
                        if let task = try? JSONDecoder().decode(DailyTask.self, from: data) { tasks.append(task) }
                    }
                }
                result = .success(tasks)
            } catch {
                result = .failure(error)
            }
        }
        if let coordinationError { return .failure(coordinationError) }
        return result
    }
}
