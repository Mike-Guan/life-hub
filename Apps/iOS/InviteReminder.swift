import Foundation
import HubCore
import UserNotifications

// The one push a day (L2 in CLAUDE.md). Scheduled for when the need has lasted long enough, and
// dropped again when a later refresh finds the need gone. Shared with the Screen Time extension.
/// Schedules today's invite notification.
enum InviteReminder {
    /// Category the notification content extension draws RUNNER for.
    static let category = "invite"
    /// Category of the scrolling-at-work notice, which has no 走 button.
    static let workCategory = "inviteWork"
    /// Key in the notification's `userInfo` for the need's raw value.
    static let needKey = "need"
    static let requestID = "invite"
    /// The invite's 走 button, which starts the walk to the gym.
    static let goAction = "go"

    /// Replaces the scheduled invite with one for `reading`, or removes it when there should be none.
    static func plan(_ reading: NeedReading?, now: Date = .now) {
        let defaults = AppGroup.defaults
        var log = InviteLog.stored(in: defaults).settled(now: now)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        log.pendingAt = nil
        let bedtime = BedtimeSchedule.stored(in: defaults)
        let at = NeedEngine.inviteTime(for: reading, now: now, lastInviteAt: log.lastSentAt, bedtime: bedtime)
        if let reading, let at {
            let content = UNMutableNotificationContent()
            content.title = "HAKU"
            content.body = NeedEngine.inviteText(for: reading.need)
            content.sound = .default
            content.categoryIdentifier = reading.need == .slacking ? workCategory : category
            content.userInfo = [needKey: reading.need.rawValue]
            let delay = max(at.timeIntervalSince(now), 1)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            // The completion handler form, so the Screen Time extension doesn't have to wait for it.
            let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
            log.pendingAt = at
        }
        log.store(in: defaults)
    }

    /// The text of the invite sent for `reading`, or `nil` when none went out for it.
    static func sent(for reading: NeedReading?) -> String? {
        guard let reading, let sent = InviteLog.stored(in: AppGroup.defaults).lastSentAt else { return nil }
        return sent >= reading.since ? NeedEngine.inviteText(for: reading.need) : nil
    }
}
