import Foundation
import Observation

// M0 persists to a local JSON file. SwiftData + CloudKit replace the storage later; the
// `ModeChange` contract stays the same.
/// Owns the mode log on this device. Single writer for `ModeLog`.
@MainActor
@Observable
public final class ModeStore {
    public private(set) var log: ModeLog
    /// Last load or save failure, for the UI to show.
    public private(set) var lastError: String?
    public let deviceID: String

    @ObservationIgnored private var file: LogFile<ModeLog>

    /// - Parameter fileURL: where the log lives; `nil` keeps everything in memory (previews, tests).
    public init(fileURL: URL?, deviceID: String) {
        var file = LogFile<ModeLog>(url: fileURL, name: "mode 记录")
        var log = ModeLog()
        let error = file.load(into: &log)
        self.file = file
        self.deviceID = deviceID
        self.log = log
        self.lastError = error
    }

    public var current: Mode? { log.current?.mode }
    public var currentSince: Date? { log.current?.at }

    /// Switches mode. A manual switch to the current mode is recorded when that mode was set
    /// automatically, so it counts as Mike confirming it.
    /// - Returns: `false` when nothing was recorded.
    @discardableResult
    public func switchTo(
        _ mode: Mode,
        source: ModeChange.Source = .manual,
        tag: String? = nil,
        at date: Date = .now
    ) -> Bool {
        if mode == current {
            guard source.isManual, let latest = log.current, !latest.source.isManual else { return false }
        }
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

    private func save() {
        lastError = file.save(&log)
    }

    static let encoder = HubJSON.encoder()
    static let decoder = HubJSON.decoder()
}

extension ModeStore {
    // Per bundle id so DEV, STG and PROD builds never share data on the Mac.
    /// The store the apps use: `Application Support/<bundle id>/mode-log.json`, with a stable device id.
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
