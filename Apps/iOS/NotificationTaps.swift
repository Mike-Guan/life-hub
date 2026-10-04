import UserNotifications

/// Receives taps on the app's notifications and passes on the off-work one and the invite's 走.
final class NotificationTaps: NSObject, UNUserNotificationCenterDelegate, Sendable {
    private let onOffWork: @MainActor @Sendable (Date) -> Void
    private let onGo: @MainActor @Sendable (Date) -> Void

    /// - Parameters:
    ///   - onOffWork: called with the delivery date when the off-work notice is opened.
    ///   - onGo: called with the tap time when the invite's 走 button is tapped.
    init(
        onOffWork: @escaping @MainActor @Sendable (Date) -> Void,
        onGo: @escaping @MainActor @Sendable (Date) -> Void
    ) {
        self.onOffWork = onOffWork
        self.onGo = onGo
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if response.actionIdentifier == InviteReminder.goAction {
            await onGo(.now)
            return
        }
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let notification = response.notification
        guard notification.request.content.categoryIdentifier == OffWorkReminder.category else { return }
        let date = notification.date
        await onOffWork(date)
    }
}
