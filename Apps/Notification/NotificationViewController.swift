import CompanionKit
import HubCore
import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI

/// Shows RUNNER in the expanded notification: sleepy at bedtime, getting up for an invite, off duty after work.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private var host: UIHostingController<CompanionView>?

    nonisolated func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        let invites = [InviteReminder.category, InviteReminder.workCategory]
        let invite = invites.contains(content.categoryIdentifier) ? content.body : nil
        let need = (content.userInfo[InviteReminder.needKey] as? String).flatMap(CompanionNeed.init(rawValue:))
        let offWork = content.categoryIdentifier == OffWorkReminder.category
        let bedtime: Bedtime = invite == nil && !offWork ? .on : .off
        MainActor.assumeIsolated { show(invite: invite, need: need, bedtime: bedtime, offWork: offWork) }
    }

    private func show(invite: String?, need: CompanionNeed?, bedtime: Bedtime, offWork: Bool) {
        // The app writes the snapshot; the notification only reads the current mode from it.
        // Off work shows the chill outfit the schedule is about to switch to.
        let mode = offWork ? .chill : AppGroup.container.snapshotURL.flatMap(WidgetSnapshot.read(from:))?.mode
        let moment: CompanionMoment? =
            switch need {
            case .slacking: .slacking
            case .sitting: .stiff
            default: GymDeparture.moment(activity: nil, need: need, departing: false)
            }
        let runner = CompanionView(
            mode: mode,
            need: need,
            moment: moment,
            invite: invite,
            bedtime: bedtime,
            style: .notification,
            showsBubble: false
        )
        // didReceive runs again when the notification is updated; reuse the view then.
        if let host {
            host.rootView = runner
            return
        }
        let host = UIHostingController(rootView: runner)
        self.host = host
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
