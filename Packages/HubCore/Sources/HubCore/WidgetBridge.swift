import Foundation
import Observation

/// Moves widget changes into the stores and writes the snapshot widgets read.
@MainActor
@Observable
public final class WidgetBridge {
    /// Last failure, for the UI to show.
    public private(set) var lastError: String?
    public let container: HubContainer
    public var bedtime: BedtimeSchedule

    public init(container: HubContainer, bedtime: BedtimeSchedule = .standard) {
        self.container = container
        self.bedtime = bedtime
    }

    /// Applies pending widget changes, then rewrites the snapshot.
    /// - Returns: how many inbox items were applied or already stored.
    @discardableResult
    public func sync(mode: ModeStore, energy: EnergyStore, now: Date = .now, calendar: Calendar = .current) -> Int {
        let applied = container.inbox.drain { item in
            switch item {
            case .mode(let change):
                mode.apply(change)
                return mode.lastError == nil
            case .energy(let event):
                energy.record(event)
                return energy.lastError == nil
            }
        }
        writeSnapshot(mode: mode, energy: energy, now: now, calendar: calendar)
        return applied
    }

    /// Writes the snapshot for `now`.
    public func writeSnapshot(mode: ModeStore, energy: EnergyStore, now: Date = .now, calendar: Calendar = .current) {
        guard let url = container.snapshotURL else { return }
        let snapshot = WidgetSnapshot(
            log: mode.log,
            energy: energy.reading(now: now, calendar: calendar)?.level,
            bedtime: bedtime.state(at: now, calendar: calendar),
            now: now
        )
        do {
            try snapshot.write(to: url)
            lastError = nil
        } catch {
            lastError = "小组件数据没写进去：\(error.localizedDescription)"
        }
    }
}
