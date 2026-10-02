import Foundation
import Observation

/// Owns the mode log on this device. Single writer for `ModeLog`.
///
/// M0 persists to a local JSON file. SwiftData + CloudKit replace the storage later; the
/// `ModeChange` contract stays the same.
@MainActor
@Observable
public final class ModeStore {
    public private(set) var log: ModeLog
    /// Last load/save failure, shown in the UI instead of being swallowed.
    public private(set) var lastError: String?
    public let deviceID: String

    @ObservationIgnored private let fileURL: URL?

    /// - Parameter fileURL: where the log lives; `nil` keeps everything in memory (previews, tests).
    public init(fileURL: URL?, deviceID: String) {
        self.fileURL = fileURL
        self.deviceID = deviceID
        self.log = ModeLog()
        load()
    }

    public var current: Mode? { log.current?.mode }
    public var currentSince: Date? { log.current?.at }

    /// Switches mode. Returns false when already in that mode, so callers don't replay effects.
    @discardableResult
    public func switchTo(
        _ mode: Mode,
        source: ModeChange.Source = .manual,
        tag: String? = nil,
        at date: Date = .now
    ) -> Bool {
        guard mode != current else { return false }
        log.changes.append(ModeChange(mode: mode, source: source, tag: tag, at: date, deviceID: deviceID))
        save()
        return true
    }

    public func segments(on day: Date, now: Date = .now) -> [ModeSegment] {
        log.segments(on: day, now: now)
    }

    public func snapshot(now: Date = .now) -> WidgetSnapshot {
        WidgetSnapshot(log: log, now: now)
    }

    private func load() {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            log = try Self.decoder.decode(ModeLog.self, from: data)
            lastError = nil
        } catch {
            // Keep the unreadable file aside so the next save can't overwrite it.
            let backup = fileURL.deletingPathExtension()
                .appendingPathExtension("corrupt-\(Int(Date.now.timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            lastError = "mode 记录读不出来，已备份到 \(backup.lastPathComponent)：\(error.localizedDescription)"
        }
    }

    private func save() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try Self.encoder.encode(log)
            try data.write(to: fileURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = "保存 mode 记录失败：\(error.localizedDescription)"
        }
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension ModeStore {
    /// The store the apps use: `Application Support/<bundle id>/mode-log.json`, with a stable device id.
    /// The folder is per bundle id so DEV, STG and PROD builds never share data on the Mac.
    public static func live(defaults: UserDefaults = .standard, bundle: Bundle = .main) -> ModeStore {
        let key = "deviceID"
        let deviceID: String
        if let existing = defaults.string(forKey: key) {
            deviceID = existing
        } else {
            #if os(iOS)
            deviceID = "iphone-\(UUID().uuidString)"
            #else
            deviceID = "mac-\(UUID().uuidString)"
            #endif
            defaults.set(deviceID, forKey: key)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let folder = bundle.bundleIdentifier ?? "LifeHub"
        let url = base?.appending(path: folder, directoryHint: .isDirectory).appending(path: "mode-log.json")
        return ModeStore(fileURL: url, deviceID: deviceID)
    }

    /// In-memory store with some history, for SwiftUI previews.
    public static func preview(now: Date = .now) -> ModeStore {
        let store = ModeStore(fileURL: nil, deviceID: "preview")
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let plan: [(Int, Mode, ModeChange.Source)] = [
            (9, .work, .schedule), (19, .boxing, .location), (21, .chill, .manual),
        ]
        for (hour, mode, source) in plan {
            if let at = calendar.date(byAdding: .hour, value: hour, to: start), at <= now {
                store.switchTo(mode, source: source, at: at)
            }
        }
        return store
    }
}
