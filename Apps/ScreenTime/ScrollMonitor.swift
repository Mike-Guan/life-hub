import DeviceActivity
import Foundation
import HubCore

// Screen Time runs this in its own process. It never sees how long Mike used the apps, only that
// a threshold was reached. The app may not run, so the notice is scheduled from here.
/// Records Screen Time reports on the picked apps, for the whole day and for work hours, and schedules
/// the day's notice.
final class ScrollMonitor: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        let now = Date.now
        if ScrollWatch.events.values.contains(event) {
            ScrollWatch.recordReport(at: now)
        } else if ScrollWatch.isWorkEvent(event) {
            ScrollWatch.recordWorkReport(at: now)
        } else {
            return
        }
        let presence = PlacePresence.stored(in: AppGroup.defaults)
        let signals = NeedSignals(
            scrollThresholdAt: ScrollWatch.reachedAt,
            scrollSeenAt: ScrollWatch.seenAt,
            atHomeSince: presence.since(.home),
            homeKnown: PlaceSettings.stored(in: AppGroup.defaults)[.home] != nil,
            atGym: presence.since(.gym) != nil,
            slackThresholdAt: ScrollWatch.workReachedAt,
            slackSeenAt: ScrollWatch.workSeenAt,
            // Without these the plan below would drop a pending sitting notice.
            sit: SitState.stored(in: AppGroup.defaults),
            mode: AppGroup.container.snapshotURL.flatMap(WidgetSnapshot.read(from:))?.mode
        )
        let days = AppGroup.activityDays(now: now)
        let work = ModeRules.stored(in: AppGroup.defaults)
        let reading = NeedEngine.need(signals, now: now, rules: AppGroup.needRules(now: now), days: days, work: work)
        InviteReminder.plan(reading, signals: signals, now: now)
    }
}
