import Foundation
import HubCore
import UserNotifications

// Mike asked for it in PRD v4.2; it is not the daily invite, so it doesn't use that slot.
/// The work-day notice shortly before the end of work hours, only on days Mike is at work.
enum OffWorkReminder {
    /// Category the notification content extension draws HAKU for.
    static let category = "offWork"
    static let requestID = "off-work-today"
    // Builds before 2026-10-05 set one repeating notice per weekday.
    private static let oldIDs = (1...7).map { "off-work-\($0)" }

    // Rescheduled on every app open, mode change and place event, so a day Mike isn't at work has none.
    /// Replaces today's notice with one for `rules`, or removes it when Mike isn't at work.
    /// Call after notification permission is asked.
    /// - Parameters:
    ///   - mode: the current mode.
    ///   - atOffice: whether Mike is at the office.
    /// - Returns: an error message for the UI, or `nil` when the notice is set or not needed.
    static func schedule(_ rules: ModeRules, mode: Mode?, atOffice: Bool, now: Date = .now) async -> String? {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: oldIDs + [requestID])
        let time = rules.offWorkNotice(on: now, mode: mode, atOffice: atOffice)
        notePlan(time, mode: mode, atOffice: atOffice, now: now)
        guard let time else { return nil }
        let content = UNMutableNotificationContent()
        content.title = "快下班了"
        content.body = "灵魂可以先走。"
        content.sound = .default
        content.categoryIdentifier = category
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        do {
            try await center.add(UNNotificationRequest(identifier: requestID, content: content, trigger: trigger))
            return nil
        } catch {
            return "下班提醒没设上：\(error.localizedDescription)"
        }
    }

    // Issue #129: the notice and the days without one, once per change.
    /// Adds today's notice plan to the decision log.
    private static func notePlan(_ time: Date?, mode: Mode?, atOffice: Bool, now: Date) {
        var signals = [DecisionLog.subjectKey: "offWork", "atOffice": atOffice ? "yes" : "no"]
        signals["mode"] = mode?.rawValue
        let decision = Decision(
            kind: .push,
            action: time == nil ? Decision.noAction : "offWork",
            target: time,
            signals: signals,
            at: now,
            deviceID: HubDevice.id(defaults: AppGroup.defaults)
        )
        let error = DecisionLog.update(at: AppGroup.container.decisionLogURL, now: now) { $0.appendIfChanged(decision) }
        DecisionLog.keep(error, in: AppGroup.defaults)
    }
}
