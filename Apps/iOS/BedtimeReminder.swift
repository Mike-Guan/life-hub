import HubCore
import UserNotifications

// Mike's explicit exception to the one-push-a-day rule (CLAUDE.md): one reminder, no follow-up,
// nothing logged about when he sleeps.
/// The daily local notification at bedtime.
enum BedtimeReminder {
    /// Category the notification content extension draws RUNNER for.
    static let category = "bedtime"
    static let requestID = "bedtime-daily"

    /// Asks for permission, then replaces the daily reminder with one at `schedule`'s start time.
    /// - Returns: an error message for the UI, or `nil` when the reminder is set.
    static func schedule(_ schedule: BedtimeSchedule) async -> String? {
        let center = UNUserNotificationCenter.current()
        // This replaces every category, so the invite's is registered here too.
        center.setNotificationCategories([
            UNNotificationCategory(identifier: category, actions: [], intentIdentifiers: []),
            UNNotificationCategory(
                identifier: InviteReminder.category,
                actions: [UNNotificationAction(identifier: InviteReminder.goAction, title: "走")],
                intentIdentifiers: []
            ),
            UNNotificationCategory(identifier: OffWorkReminder.category, actions: [], intentIdentifiers: []),
        ])
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                return "通知被关掉了，睡觉提醒发不出来。可以在系统设置里打开。"
            }
            let content = UNMutableNotificationContent()
            content.title = "该睡了"
            content.body = "HAKU 已经在打哈欠了。"
            content.sound = .default
            content.categoryIdentifier = category
            let trigger = UNCalendarNotificationTrigger(dateMatching: schedule.startComponents, repeats: true)
            center.removePendingNotificationRequests(withIdentifiers: [requestID])
            try await center.add(UNNotificationRequest(identifier: requestID, content: content, trigger: trigger))
            return nil
        } catch {
            return "睡觉提醒没设上：\(error.localizedDescription)"
        }
    }
}
