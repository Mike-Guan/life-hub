import Foundation

/// One change made outside the app, for example by a widget button.
public enum InboxItem: Codable, Equatable, Sendable {
    case mode(ModeChange)
    case energy(EnergyEvent)

    public var id: UUID {
        switch self {
        case .mode(let change): change.id
        case .energy(let event): event.id
        }
    }

    public var at: Date {
        switch self {
        case .mode(let change): change.at
        case .energy(let event): event.at
        }
    }
}

// Widgets run in their own process. Writing straight into the logs would race the app, so they
// drop one file per change here and the app, as the single writer, applies them.
/// A folder of pending changes. Widgets post, the app drains.
public struct EventInbox: Sendable {
    public let folder: URL?

    public init(folder: URL?) {
        self.folder = folder
    }

    /// Writes `item` to its own file, named by its id.
    /// - Throws: file system or encoding errors.
    public func post(_ item: InboxItem) throws {
        guard let folder else { return }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try HubJSON.encoder().encode(item).write(to: fileURL(for: item.id, in: folder), options: .atomic)
    }

    /// Passes each pending item to `apply`, oldest first, and deletes the ones it accepts.
    /// Files that can't be decoded stay for a newer build.
    /// - Parameter apply: returns `true` once the item is stored and its file can go.
    /// - Returns: how many items were accepted.
    @discardableResult
    public func drain(_ apply: (InboxItem) -> Bool) -> Int {
        guard let folder else { return 0 }
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        let decoder = HubJSON.decoder()
        var pending: [(file: URL, item: InboxItem)] = []
        for file in urls where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file), let item = try? decoder.decode(InboxItem.self, from: data) {
                pending.append((file, item))
            }
        }
        pending.sort { $0.item.at < $1.item.at }
        var accepted = 0
        for (file, item) in pending {
            guard apply(item) else { continue }
            try? FileManager.default.removeItem(at: file)
            accepted += 1
        }
        return accepted
    }

    private func fileURL(for id: UUID, in folder: URL) -> URL {
        folder.appending(path: "\(id.uuidString).json")
    }
}
