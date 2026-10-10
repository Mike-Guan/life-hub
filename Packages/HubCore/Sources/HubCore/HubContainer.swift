import Foundation

/// The folder that holds the hub's files on this device.
public struct HubContainer: Sendable {
    /// `nil` keeps everything in memory (previews, tests).
    public let folder: URL?

    public init(folder: URL?) {
        self.folder = folder
    }

    /// The App Group container, or `nil` when this build has no App Group entitlement.
    public static func appGroup(_ identifier: String) -> HubContainer? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier).map(HubContainer.init)
    }

    // Per bundle id so DEV, STG and PROD builds never share data on the Mac.
    /// `Application Support/<bundle id>/`.
    public static func applicationSupport(bundle: Bundle = .main) -> HubContainer {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let name = bundle.bundleIdentifier ?? "LifeHub"
        return HubContainer(folder: base?.appending(path: name, directoryHint: .isDirectory))
    }

    public var modeLogURL: URL? { file("mode-log.json") }
    public var energyLogURL: URL? { file("energy-log.json") }
    public var canLedgerURL: URL? { file("can-ledger.json") }
    public var snapshotURL: URL? { file("widget-snapshot.json") }
    /// What the Apple Watch last got from the iPhone, in the watch's own container.
    public var watchPayloadURL: URL? { file("watch-payload.json") }
    /// The public card, kept apart from every private log.
    public var publicCardURL: URL? { file("public-card.json") }
    /// The rule decisions, which never leave the iPhone.
    public var decisionLogURL: URL? { file("decision-log.json") }
    public var inbox: EventInbox { EventInbox(folder: folder?.appending(path: "inbox", directoryHint: .isDirectory)) }

    // M0 builds kept the mode log in Application Support. Moving it keeps Mike's history.
    /// Moves the mode and energy logs from `old` when this container doesn't have them yet.
    /// - Returns: error messages for the UI, empty when nothing failed.
    public func adoptLogs(from old: HubContainer) -> [String] {
        let pairs = [(old.modeLogURL, modeLogURL), (old.energyLogURL, energyLogURL)]
        var errors: [String] = []
        let files = FileManager.default
        for case (let from?, let to?) in pairs where from != to {
            guard files.fileExists(atPath: from.path), !files.fileExists(atPath: to.path) else { continue }
            do {
                try files.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
                try files.moveItem(at: from, to: to)
            } catch {
                errors.append("搬不动旧记录 \(from.lastPathComponent)：\(error.localizedDescription)")
            }
        }
        return errors
    }

    /// Records a widget change: posts it to the inbox and updates the snapshot so widgets show it now.
    /// - Throws: file system or encoding errors from the inbox.
    public func post(_ item: InboxItem) throws {
        try inbox.post(item)
        guard let url = snapshotURL, let snapshot = WidgetSnapshot.read(from: url) else { return }
        // The inbox already holds the change; a stale snapshot only delays the widget until the app opens.
        try? snapshot.applying(item).write(to: url)
    }

    // Only the hub's own files: the App Group container also holds the shared user defaults.
    /// Deletes every hub file and the widget inbox, as on a fresh install.
    /// - Returns: error messages for the UI, empty when nothing failed.
    public func eraseFiles() -> [String] {
        guard let folder else { return [] }
        let files = FileManager.default
        let names = (try? files.contentsOfDirectory(atPath: folder.path)) ?? []
        var errors: [String] = []
        for name in names.sorted() where name.hasSuffix(".json") || name == "inbox" {
            do {
                try files.removeItem(at: folder.appending(path: name))
            } catch {
                errors.append("删不掉 \(name)：\(error.localizedDescription)")
            }
        }
        return errors
    }

    private func file(_ name: String) -> URL? {
        folder?.appending(path: name)
    }
}

/// This device's id, stored in user defaults.
public enum HubDevice {
    static let key = "deviceID"

    // The id stays, so records written after the erase keep this device's name.
    /// Removes every key in `defaults` but this device's id, as on a fresh install.
    public static func eraseDefaults(_ defaults: UserDefaults) {
        for key in defaults.dictionaryRepresentation().keys where key != Self.key {
            defaults.removeObject(forKey: key)
        }
    }

    /// The id kept in `defaults`, created on first use.
    public static func id(defaults: UserDefaults) -> String {
        if let existing = defaults.string(forKey: key) {
            return existing
        }
        #if os(iOS)
        let id = "iphone-\(UUID().uuidString)"
        #else
        let id = "mac-\(UUID().uuidString)"
        #endif
        defaults.set(id, forKey: key)
        return id
    }
}
