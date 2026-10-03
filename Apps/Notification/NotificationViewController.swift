import CompanionKit
import HubCore
import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI

/// Shows sleepy RUNNER in the expanded bedtime notification.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    override func viewDidLoad() {
        super.viewDidLoad()
        // The app writes the snapshot; the notification only reads the current mode from it.
        let mode = AppGroup.container.snapshotURL.flatMap(WidgetSnapshot.read(from:))?.mode
        let runner = CompanionView(mode: mode, bedtime: .on, style: .notification, showsBubble: false)
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

    nonisolated func didReceive(_ notification: UNNotification) {}
}
