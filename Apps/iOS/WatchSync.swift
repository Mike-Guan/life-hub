import Foundation
import HubCore
import WatchConnectivity

// Issue #160. Sends what the iPhone widgets read to the Apple Watch app, which stores it for its own
// widgets. Application context keeps only the latest payload, so a watch that was away catches up on the
// next launch; complication transfers wake the watch app while HAKU is on the watch face.
/// Sends HAKU's state to the Apple Watch.
final class WatchSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    // No stored state besides the session, which WatchConnectivity makes safe to use from any thread.
    static let shared = WatchSync()

    /// Starts the session; the latest state goes out once it is active.
    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Sends the snapshot the widgets read, with the wardrobe and bedtime, when a watch app is installed.
    func send() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        guard let url = AppGroup.container.snapshotURL, let snapshot = WidgetSnapshot.read(from: url) else { return }
        let payload = WatchPayload(
            snapshot: snapshot,
            wardrobe: Wardrobe.stored(in: AppGroup.defaults),
            bedtime: BedtimeSchedule.stored(in: AppGroup.defaults),
            persona: Persona.stored(in: AppGroup.defaults)
        )
        // Complication transfers have a daily budget (about 50), so they go out only when what the watch
        // face draws changed.
        let changed = WatchPayload(message: session.applicationContext).map { !payload.drawsLike($0) } ?? true
        guard let message = payload.message else { return }
        do {
            try session.updateApplicationContext(message)
        } catch {
            Dogfood.note("watch", "没发到手表：\(error.localizedDescription)")
        }
        if changed, session.isComplicationEnabled, session.remainingComplicationUserInfoTransfers > 0 {
            session.transferCurrentComplicationUserInfo(message)
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error { Dogfood.note("watch", "手表连接没建立：\(error.localizedDescription)") }
        send()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    // After switching to another watch, the session has to be activated again.
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        send()
    }
}
