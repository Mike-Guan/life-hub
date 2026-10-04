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
    /// What RUNNER acts out now; the app sets it before syncing.
    public var need: NeedReading?

    public init(container: HubContainer, bedtime: BedtimeSchedule = .standard) {
        self.container = container
        self.bedtime = bedtime
    }

    /// Applies pending widget and shortcut changes, then rewrites the snapshot.
    /// - Parameter expenses: where payments go; without it they stay in the inbox.
    /// - Returns: how many inbox items were applied or already stored.
    @discardableResult
    public func sync(
        mode: ModeStore,
        energy: EnergyStore,
        expenses: ExpenseStore? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let applied = container.inbox.drain { item in
            switch item {
            case .mode(let change):
                mode.apply(change)
                return mode.lastError == nil
            case .energy(let event):
                energy.record(event)
                return energy.lastError == nil
            case .expense(let expense):
                guard let expenses else { return false }
                expenses.record(expense)
                return expenses.lastError == nil
            }
        }
        writeSnapshot(mode: mode, energy: energy, now: now, calendar: calendar)
        return applied
    }

    /// Writes the snapshot for `now`.
    public func writeSnapshot(mode: ModeStore, energy: EnergyStore, now: Date = .now, calendar: Calendar = .current) {
        guard let url = container.snapshotURL else { return }
        let reading = energy.reading(now: now, calendar: calendar)
        let state = bedtime.state(at: now, calendar: calendar)
        var snapshot = WidgetSnapshot(log: mode.log, energy: reading?.level, bedtime: state, now: now)
        snapshot.need = need?.need
        snapshot.needUntil = need?.until
        let current = mode.current
        let scene = HakuLines.scene(mode: current, need: need?.need, energy: reading?.level, bedtime: state)
        let after = HakuLines.scene(mode: current, need: nil, energy: reading?.level, bedtime: state)
        snapshot.line = scene.map { HakuLines.line($0, at: now, calendar: calendar) }
        snapshot.lineAfterNeed = after.map { HakuLines.line($0, at: now, calendar: calendar) }
        snapshot.nextNeed = NeedEngine.nextScheduled(after: now, calendar: calendar)
        if let next = snapshot.nextNeed {
            snapshot.nextNeed?.line = HakuLines.line(.boxingWarmup, at: next.from, calendar: calendar)
        }
        do {
            try snapshot.write(to: url)
            lastError = nil
        } catch {
            lastError = "小组件数据没写进去：\(error.localizedDescription)"
        }
    }
}
