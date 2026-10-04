import HubCore
import SwiftUI
import WidgetKit

@main
struct LifeHubWidgets: WidgetBundle {
    var body: some Widget {
        StatusWidget()
        ModeWidget()
        EnergyWidget()
        BoxingCountdownWidget()
    }
}

/// What every widget draws from: the app's snapshot at one point in time.
struct HubEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let bedtime: Bedtime
    var wardrobe = Wardrobe()
    /// What HAKU does alongside Mike at `date`.
    var activity: CompanionActivity?

    var mode: Mode? { snapshot?.mode }
    var energy: EnergyLevel? { snapshot?.energy(at: date) }
    var need: CompanionNeed? { snapshot?.need(at: date) }
    var needSince: Date? { snapshot?.needSince(at: date) }

    /// One short line from HAKU: what it does alongside Mike, its bedtime line, else the app's line for
    /// now, else today's energy.
    var detail: String {
        if let activity { return activity.reason }
        if bedtime == .on { return HakuLines.line(.bedtime, at: date) }
        if let line = snapshot?.line(at: date) { return line }
        return energy.map { "电量\($0.title)" } ?? "电量未知"
    }
}

// Widgets only read the snapshot the app writes (lessons DW-04).
/// Reads the snapshot and redraws at the next bedtime change and day start.
struct HubProvider: TimelineProvider {
    func placeholder(in context: Context) -> HubEntry {
        HubEntry(
            date: .now,
            snapshot: WidgetSnapshot(mode: .work, since: nil, energy: .okay, updatedAt: .now),
            bedtime: .off
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HubEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entries(after: .now)[0])
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HubEntry>) -> Void) {
        completion(Timeline(entries: entries(after: .now), policy: .atEnd))
    }

    private func entries(after now: Date) -> [HubEntry] {
        let snapshot = AppGroup.container.snapshotURL.flatMap(WidgetSnapshot.read(from:))
        let schedule = BedtimeSchedule.stored(in: AppGroup.defaults)
        let work = ModeRules.stored(in: AppGroup.defaults)
        let days = ActivityDays.stored(in: AppGroup.defaults)
        let starts = ActivityEngine.startTimes(on: now, days: days, work: work)
        let needTimes = (snapshot?.needTimes ?? []) + starts
        let dates = WidgetSnapshot.timelineDates(after: now, bedtime: schedule, needTimes: needTimes)
        let wardrobe = Wardrobe.stored(in: AppGroup.defaults)
        let signals = ActivitySignals(
            presence: PlacePresence.stored(in: AppGroup.defaults),
            workouts: snapshot?.workouts ?? []
        )
        return dates.map { date in
            HubEntry(
                date: date,
                snapshot: snapshot,
                bedtime: schedule.state(at: date),
                wardrobe: wardrobe,
                activity: ActivityEngine.activity(signals, days: days, work: work, bedtime: schedule, now: date)
            )
        }
    }
}
