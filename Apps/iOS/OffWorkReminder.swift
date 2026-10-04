import HubCore
import UserNotifications

// Mike asked for it in PRD v4.2; it is not the daily invite, so it doesn't use that slot.
/// The weekday notice shortly before the end of work hours.
enum OffWorkReminder {
    /// Category the notification content extension draws HAKU for.
    static let category = "offWork"
    static let requestPrefix = "off-work-"

    /// Replaces the weekday notices with ones for `rules`. Call after notification permission is asked.
    /// - Returns: an error message for the UI, or `nil` when the notices are set.
    static func schedule(_ rules: ModeRules) async -> String? {
        let center = UNUserNotificationCenter.current()
        let old = (1...7).map { "\(requestPrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: old)
        let content = UNMutableNotificationContent()
        content.title = "快下班了"
        content.body = "灵魂可以先走。"
        content.sound = .default
        content.categoryIdentifier = category
        do {
            for time in rules.offWorkNotices {
                let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
                let id = "\(requestPrefix)\(time.weekday ?? 0)"
                try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
            return nil
        } catch {
            return "下班提醒没设上：\(error.localizedDescription)"
        }
    }
}
