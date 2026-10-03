import HubCore
import SwiftUI
import WidgetKit

@main
struct LifeHubWidgets: WidgetBundle {
    var body: some Widget {
        StatusWidget()
        ModeWidget()
        EnergyWidget()
    }
}

/// What every widget draws from: the app's snapshot at one point in time.
struct HubEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let bedtime: Bedtime

    var mode: Mode? { snapshot?.mode }
    var energy: EnergyLevel? { snapshot?.energy(at: date) }
    var need: CompanionNeed? { snapshot?.need(at: date) }

    /// One short line: bedtime, else why RUNNER looks the way it does, else today's energy.
    var detail: String {
        if bedtime == .on { return "该睡了" }
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
        let dates = WidgetSnapshot.timelineDates(after: now, bedtime: schedule, needUntil: snapshot?.needUntil)
        return dates.map { date in
            HubEntry(date: date, snapshot: snapshot, bedtime: schedule.state(at: date))
        }
    }
}
