import UserNotifications

/// Receives taps on the app's notifications and passes the off-work one on.
final class NotificationTaps: NSObject, UNUserNotificationCenterDelegate, Sendable {
    private let onOffWork: @MainActor @Sendable (Date) -> Void

    /// - Parameter onOffWork: called with the delivery date when the off-work notice is opened.
    init(onOffWork: @escaping @MainActor @Sendable (Date) -> Void) {
        self.onOffWork = onOffWork
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let notification = response.notification
        guard notification.request.content.categoryIdentifier == OffWorkReminder.category else { return }
        let date = notification.date
        await onOffWork(date)
    }
}
