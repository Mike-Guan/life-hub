import HubCore
import UserNotifications

// Mike's explicit exception to the one-push-a-day rule (CLAUDE.md): one reminder, no follow-up,
// nothing logged about when he sleeps.
/// The daily local notification at bedtime.
enum BedtimeReminder {
    /// Category the notification content extension draws RUNNER for.
    static let category = "bedtime"
    static let requestID = "bedtime-daily"

    /// Asks for permission, then replaces the daily reminder with one at `schedule`'s start time, in `persona`'s name.
    /// Removes it when `on` is false or no bedtime is set.
    /// - Returns: an error message for the UI, or `nil` when the reminder is set or removed.
    static func schedule(_ schedule: BedtimeSchedule, on: Bool, persona: Persona) async -> String? {
        let center = UNUserNotificationCenter.current()
        // This replaces every category, so the invite's is registered here too.
        center.setNotificationCategories([
            UNNotificationCategory(identifier: category, actions: [], intentIdentifiers: []),
            UNNotificationCategory(
                identifier: InviteReminder.category,
                actions: [UNNotificationAction(identifier: InviteReminder.goAction, title: "走")],
                intentIdentifiers: []
            ),
            UNNotificationCategory(identifier: InviteReminder.workCategory, actions: [], intentIdentifiers: []),
            UNNotificationCategory(identifier: OffWorkReminder.category, actions: [], intentIdentifiers: []),
        ])
        do {
            // Asked even with the reminder off: the off-work notice and invites rely on it.
            let allowed = try await center.requestAuthorization(options: [.alert, .sound])
            guard let time = schedule.reminderTime(on: on) else {
                center.removePendingNotificationRequests(withIdentifiers: [requestID])
                return nil
            }
            guard allowed else {
                return "通知被关掉了，睡觉提醒发不出来。可以在系统设置里打开。"
            }
            let content = UNMutableNotificationContent()
            content.title = "到你定的睡觉时间了"
            content.body = "\(persona.title) 已经在打哈欠了。"
            content.sound = .default
            content.categoryIdentifier = category
            let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
            center.removePendingNotificationRequests(withIdentifiers: [requestID])
            try await center.add(UNNotificationRequest(identifier: requestID, content: content, trigger: trigger))
            return nil
        } catch {
            return "睡觉提醒没设上：\(error.localizedDescription)"
        }
    }
}
