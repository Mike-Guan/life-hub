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
    /// The timed tasks from yesterday to tomorrow as of the last read, `nil` while not linked.
    private(set) var plan: DailyPlan?
    /// The celebration for the newest task ticked done since the read before, `nil` when none.
    private(set) var done: CompanionEvent?
    /// Last failure, for the UI to show.
    private(set) var lastError: String?

    private static let bookmarkKey = "dailyFolderBookmark"
    private static let seenKey = "dailySeenDone"

    init() {
        isOn = AppGroup.defaults.data(forKey: Self.bookmarkKey) != nil
        plan = DailyPlan.stored(in: AppGroup.defaults)
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
        AppGroup.defaults.removeObject(forKey: Self.seenKey)
        DailyPlan.clear(in: AppGroup.defaults)
        isOn = false
        tasks = []
        plan = nil
        done = nil
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
            noteDone(DailyAgenda.occurrences(read, now: .now))
            lastError = nil
        case .failure(let error):
            lastError = "读不到 Daily 的文件夹：\(error.localizedDescription)"
        }
        if stale, let fresh = try? Self.bookmark(for: folder) {
            AppGroup.defaults.set(fresh, forKey: Self.bookmarkKey)
        }
    }

    // Saved for the widgets and the Screen Time extension, which can't open Daily's folder.
    private func noteDone(_ occurrences: [DailyOccurrence]) {
        let defaults = AppGroup.defaults
        let plan = DailyPlan(occurrences: occurrences)
        plan.store(in: defaults)
        self.plan = plan
        let seen = defaults.stringArray(forKey: Self.seenKey).map(Set.init)
        let result = DailyAgenda.newlyDone(in: occurrences, seen: seen)
        defaults.set(Array(result.seen), forKey: Self.seenKey)
        if let event = result.event { done = event }
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
