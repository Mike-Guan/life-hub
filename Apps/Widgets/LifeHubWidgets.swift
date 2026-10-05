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
        GoToGymControl()
    }
}

/// What every widget draws from: the app's snapshot at one point in time.
struct HubEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let bedtime: Bedtime
    var wardrobe = Wardrobe()
    /// What HAKU does alongside Mike at `date`, `nil` while `moment` replaces the gym bag.
    var activity: CompanionActivity?
    /// The state within the mode HAKU acts out at `date`, such as vibe coding or walking to the gym.
    var moment: CompanionMoment?
    /// What today left in HAKU's world, such as a bandage after boxing.
    var traces: Set<CompanionTrace> = []
    /// HAKU's line on a day it stopped an invite Mike kept ignoring.
    var notice: String?
    /// HAKU's Sunday line about the week's change moments.
    var weekLine: String?

    var mode: Mode? { snapshot?.mode }
    var energy: EnergyLevel? { snapshot?.energy(at: date) }
    var vitals: HakuVitals { snapshot?.vitals ?? HakuVitals() }
    var need: CompanionNeed? { snapshot?.need(at: date) }
    var needSince: Date? { snapshot?.needSince(at: date) }

    /// One short line from HAKU: what it does alongside Mike, its bedtime line, else the app's line for
    /// now, else today's energy.
    var detail: String {
        if let activity { return activity.reason }
        if moment == .heading { return "出发了，包我背着" }
        if let scene = moment.flatMap(HakuLines.scene(for:)) { return HakuLines.line(scene, at: date) }
        if bedtime == .on { return HakuLines.line(.bedtime, at: date) }
        if let notice { return notice }
        if let weekLine { return weekLine }
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
        let days = AppGroup.activityDays(now: now)
        let starts = ActivityEngine.startTimes(on: now, days: days, work: work)
        let departure = GymDeparture.stored(in: AppGroup.defaults)
        let walk = [departure?.at, departure?.until].compactMap { $0 }
        let presence = PlacePresence.stored(in: AppGroup.defaults)
        let office = MomentEngine.officeTimes(since: presence.since(.office), now: now)
        let home = MomentEngine.homeTimes(since: presence.since(.home), now: now, work: work)
        let slots = WidgetSnapshot.slotDates(after: now)
        let needTimes = (snapshot?.needTimes ?? []) + starts + walk + office + home + slots
        let dates = WidgetSnapshot.timelineDates(after: now, bedtime: schedule, needTimes: needTimes)
        let wardrobe = Wardrobe.stored(in: AppGroup.defaults)
        let backoff = NudgeBackoff.stored(in: AppGroup.defaults)
        let ledger = CanLedger.read(from: AppGroup.container.canLedgerURL)
        let changes = ChangeEngine.times(log: .stored(in: AppGroup.defaults), ledger: ledger)
        let sit = SitState.stored(in: AppGroup.defaults)
        let signals = ActivitySignals(
            presence: presence,
            trainedDay: snapshot?.trainedDay,
            ranDay: snapshot?.ranDay
        )
        return dates.map { date in
            let activity = ActivityEngine.activity(signals, days: days, work: work, bedtime: schedule, now: date)
            let departing = departure?.isActive(at: date, presence: presence) ?? false
            let need = snapshot?.need(at: date)
            let moment = MomentEngine.moment(
                mode: snapshot?.mode,
                sideHustle: snapshot?.sideHustle,
                activity: activity,
                need: need,
                departing: departing,
                officeSince: presence.since(.office),
                home: snapshot?.home(since: presence.since(.home), at: date),
                stiff: sit?.isStiff(mode: snapshot?.mode, at: date) ?? false,
                now: date,
                work: work
            )
            return HubEntry(
                date: date,
                snapshot: snapshot,
                bedtime: schedule.state(at: date),
                wardrobe: wardrobe,
                activity: activity == .gymDay && moment != nil ? nil : activity,
                moment: moment,
                traces: snapshot?.traces(at: date) ?? [],
                notice: backoff.notice(at: date),
                weekLine: ChangeEngine.sundayLine(times: changes, now: date)
            )
        }
    }
}
