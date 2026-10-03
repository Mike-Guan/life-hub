import CompanionKit
import HubCore
import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI

/// Shows RUNNER in the expanded notification: sleepy at bedtime, getting up for an invite.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    nonisolated func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        let invite = content.categoryIdentifier == InviteReminder.category ? content.body : nil
        let need = (content.userInfo[InviteReminder.needKey] as? String).flatMap(CompanionNeed.init(rawValue:))
        MainActor.assumeIsolated { show(invite: invite, need: need) }
    }

    private func show(invite: String?, need: CompanionNeed?) {
        // The app writes the snapshot; the notification only reads the current mode from it.
        let mode = AppGroup.container.snapshotURL.flatMap(WidgetSnapshot.read(from:))?.mode
        let runner = CompanionView(
            mode: mode,
            need: need,
            invite: invite,
            bedtime: invite == nil ? .on : .off,
            style: .notification,
            showsBubble: false
        )
        let host = UIHostingController(rootView: runner)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }
}
