import DeviceActivity
import Foundation
import HubCore

// Screen Time runs this in its own process. It never sees how long Mike used the apps, only that
// the threshold was reached. The app may not run tonight, so the invite is scheduled from here.
/// Records when today's Screen Time threshold on the picked apps is reached and schedules the invite.
final class ScrollMonitor: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard event == ScrollWatch.event else { return }
        let now = Date.now
        ScrollWatch.reachedAt = now
        let presence = PlacePresence.stored(in: AppGroup.defaults)
        let signals = NeedSignals(
            scrollThresholdAt: now,
            atHomeSince: presence.since(.home),
            homeKnown: PlaceSettings.stored(in: AppGroup.defaults)[.home] != nil,
            atGym: presence.since(.gym) != nil
        )
        InviteReminder.plan(NeedEngine.need(signals, now: now), now: now)
    }
}
