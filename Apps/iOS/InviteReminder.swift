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
    /// - Parameter signals: what the app knows now, to judge whether the last invite was followed.
    static func plan(_ reading: NeedReading?, signals: NeedSignals? = nil, now: Date = .now) {
        let defaults = AppGroup.defaults
        var log = InviteLog.stored(in: defaults).settled(now: now)
        let backoff = judgeLastInvite(log, signals: signals, now: now)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        log.pendingAt = nil
        log.pendingNeed = nil
        let bedtime = BedtimeSchedule.stored(in: defaults)
        let energy = EnergyLog.read(from: AppGroup.container.energyLogURL)
        let at = NeedEngine.inviteTime(
            for: reading,
            now: now,
            lastInviteAt: log.lastSentAt,
            bedtime: bedtime,
            sleptShort: StateEngine.sleptShort(events: energy.events, now: now)
        )
        if let reading, let at, !backoff.isPaused(reading.need, at: at) {
            let content = UNMutableNotificationContent()
            content.title = "HAKU"
            content.body = NeedEngine.inviteText(for: reading.need, taskSoon: taskSoon(after: at))
            content.sound = .default
            // Work-time notices have no 走 button.
            let atWork = reading.need == .slacking || reading.need == .sitting
            content.categoryIdentifier = atWork ? workCategory : category
            content.userInfo = [needKey: reading.need.rawValue]
            let delay = max(at.timeIntervalSince(now), 1)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            // The completion handler form, so the Screen Time extension doesn't have to wait for it.
            let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
            log.pendingAt = at
            log.pendingNeed = reading.need
        }
        log.store(in: defaults)
    }

    // Each sent invite is judged once, as soon as the signals can tell.
    /// Records whether the last invite was followed, and returns the back-off state.
    private static func judgeLastInvite(_ log: InviteLog, signals: NeedSignals?, now: Date) -> NudgeBackoff {
        let defaults = AppGroup.defaults
        var backoff = NudgeBackoff.stored(in: defaults)
        guard let signals, let sent = log.lastSentAt, let need = log.lastNeed, backoff.judgedSentAt != sent else {
            return backoff
        }
        let departed = GymDeparture.stored(in: defaults)?.at
        let followed = NudgeBackoff.followed(need, sentAt: sent, signals: signals, departedAt: departed, now: now)
        guard let followed else { return backoff }
        backoff.record(need, followed: followed, sentAt: sent, now: now)
        backoff.store(in: defaults)
        let deviceID = HubDevice.id(defaults: defaults)
        if let moment = ChangeEngine.gotUp(need, followed: followed, sentAt: sent, deviceID: deviceID) {
            ChangeLog.note(moment, in: defaults)
        }
        return backoff
    }

    /// The text of the invite sent for `reading`, or `nil` when none went out for it.
    static func sent(for reading: NeedReading?) -> String? {
        guard let reading, let sent = InviteLog.stored(in: AppGroup.defaults).lastSentAt else { return nil }
        return sent >= reading.since ? NeedEngine.inviteText(for: reading.need, taskSoon: taskSoon(after: sent)) : nil
    }

    /// Whether a Daily task starts within the hour after `date`.
    private static func taskSoon(after date: Date) -> Bool {
        DailyPlan.stored(in: AppGroup.defaults)?.hasTask(within: DailyAgenda.inviteLead, after: date) ?? false
    }
}
