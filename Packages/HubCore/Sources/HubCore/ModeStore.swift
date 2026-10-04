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

    // Long enough to fix a mistap or a curious look at another mode, short enough to keep real switches.
    /// A manual switch this soon after the previous manual one corrects it instead of adding to the log.
    public static let correctionWindow: TimeInterval = 2 * 60

    public var current: Mode? { log.current?.mode }
    public var currentSince: Date? { log.current?.at }
    /// The 副业 state, `nil` in other modes.
    public var sideHustle: SideHustle? { log.current?.sideHustle }

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
        apply(ModeChange(mode: mode, source: source, tag: tag, at: date, deviceID: deviceID))
    }

    /// Records `change` under the same rules as `switchTo`. A change whose id is already stored is skipped.
    /// A manual change within `correctionWindow` of the previous manual one replaces it; switching back
    /// to the mode before it undoes it, so the timeline and the 2-hour auto-switch pause are as before.
    /// - Returns: `false` when nothing was recorded.
    @discardableResult
    public func apply(_ change: ModeChange) -> Bool {
        guard !log.changes.contains(where: { $0.id == change.id }) else { return false }
        if change.isSameState(as: log.current) {
            guard change.source.isManual, let latest = log.current, !latest.source.isManual else { return false }
        }
        // Soft delete keeps the corrected change in the log (one writer, nothing lost).
        let corrected = change.source.isManual ? correctableIndex(before: change) : nil
        if let index = corrected {
            log.changes[index].deletedAt = change.at
            log.changes[index].updatedAt = change.at
            log.changes[index].updatedBy = change.updatedBy
        }
        // Only an undo (back to the mode before the corrected change) adds nothing.
        if corrected == nil || !change.isSameState(as: log.current) {
            log.changes.append(change)
        }
        save()
        return true
    }

    private func correctableIndex(before change: ModeChange) -> Int? {
        guard let latest = log.current, latest.source.isManual else { return nil }
        let gap = change.at.timeIntervalSince(latest.at)
        guard gap >= 0, gap < Self.correctionWindow else { return nil }
        return log.changes.firstIndex { $0.id == latest.id }
    }

    // A state change counts as a manual change, so automatic switches wait 2 hours after it too.
    /// In 副业 mode, switches by hand to the next state. Earns no cans.
    /// - Returns: `false` outside 副业 mode or when nothing was recorded.
    @discardableResult
    public func cycleSideHustle(at date: Date = .now) -> Bool {
        guard let state = sideHustle else { return false }
        return switchTo(.money, tag: state.next.rawValue, at: date)
    }

    /// Applies what `ModeEngine` decides for `trigger`.
    /// - Returns: the change made, or `nil` when the mode stays.
    @discardableResult
    public func autoSwitch(
        _ trigger: ModeTrigger,
        rules: ModeRules = .standard,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ModeDecision? {
        guard let decision = ModeEngine.decide(trigger, log: log, now: now, rules: rules, calendar: calendar) else {
            return nil
        }
        return switchTo(decision.mode, source: decision.source, tag: decision.tag, at: now) ? decision : nil
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
    /// The store the apps use, in `container` with this device's id from `defaults`.
    public static func live(
        in container: HubContainer = .applicationSupport(),
        defaults: UserDefaults = .standard
    ) -> ModeStore {
        ModeStore(fileURL: container.modeLogURL, deviceID: HubDevice.id(defaults: defaults))
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
