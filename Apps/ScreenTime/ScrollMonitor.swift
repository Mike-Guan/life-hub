import DeviceActivity
import Foundation

// Screen Time runs this in its own process. It never sees how long Mike used the apps, only that
// the threshold was reached, and it only records that moment.
/// Records when today's Screen Time threshold on the picked apps is reached.
final class ScrollMonitor: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard event == ScrollWatch.event else { return }
        ScrollWatch.reachedAt = .now
    }
}
