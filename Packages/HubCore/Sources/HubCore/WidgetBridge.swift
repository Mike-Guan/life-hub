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
    // Kept in memory; only the day of the last workout of each kind goes into the snapshot.
    /// Workouts from the last HealthKit reading; the app sets it before syncing.
    public var workouts: [WorkoutSummary] = []
    /// The need rules for the chosen character; the app sets it before syncing.
    public var rules = NeedRules.standard

    public init(container: HubContainer, bedtime: BedtimeSchedule = .standard) {
        self.container = container
        self.bedtime = bedtime
    }

    /// Applies pending widget and shortcut changes, then rewrites the snapshot.
    /// - Returns: how many inbox items were applied or already stored.
    @discardableResult
    public func sync(
        mode: ModeStore,
        energy: EnergyStore,
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
        snapshot.needSince = need?.since
        snapshot.needUntil = need?.until
        let done = ActivitySignals(workouts: workouts, calendar: calendar)
        snapshot.trainedDay = done.trainedDay
        snapshot.ranDay = done.ranDay
        snapshot.traces = MomentEngine.traces(
            log: mode.log,
            workouts: workouts,
            energy: reading?.level,
            now: now,
            calendar: calendar
        )
        // Room traces and hidden stats belong to the picked character.
        let ledger = CanLedger.read(from: container.canLedgerURL).only(rules.persona)
        snapshot.lasting = MomentEngine.lastingTraces(log: mode.log, ledger: ledger, now: now)
        snapshot.vitals = VitalsEngine.vitals(ledger: ledger, energy: energy.log, now: now, calendar: calendar)
        snapshot.workedToday = MomentEngine.workedToday(mode.log, now: now, calendar: calendar)
        snapshot.manualAt = mode.log.active.last(where: \.source.isManual)?.at
        let current = mode.current
        let scene = HakuLines.scene(mode: current, need: need?.need, energy: reading?.level, bedtime: state)
        let after = HakuLines.scene(mode: current, need: nil, energy: reading?.level, bedtime: state)
        let persona = rules.persona
        snapshot.line = scene.map { HakuLines.line($0, at: now, calendar: calendar, persona: persona) }
        snapshot.lineAfterNeed = after.map { HakuLines.line($0, at: now, calendar: calendar, persona: persona) }
        snapshot.nextNeed = NeedEngine.nextScheduled(after: now, rules: rules, calendar: calendar)
        if let next = snapshot.nextNeed {
            snapshot.nextNeed?.line = HakuLines.line(.boxingWarmup, at: next.from, calendar: calendar, persona: persona)
        }
        do {
            try snapshot.write(to: url)
            lastError = nil
        } catch {
            lastError = "小组件数据没写进去：\(error.localizedDescription)"
        }
    }
}
