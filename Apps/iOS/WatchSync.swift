import Foundation
import HubCore
import Synchronization
import WatchConnectivity

// Issue #160. Sends what the iPhone widgets read to the Apple Watch app, which stores it for its own
// widgets. Application context keeps only the latest payload, so a watch that was away catches up on the
// next launch; complication transfers wake the watch app while HAKU is on the watch face.
/// Sends HAKU's state to the Apple Watch.
final class WatchSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    // Besides the session, which WatchConnectivity makes safe to use from any thread, only the last scenes
    // the app worked out, behind a lock, so a send from a session callback still carries them.
    static let shared = WatchSync()
    private let played = Mutex(WatchPlay())
    private let onCheck = Mutex<(@MainActor @Sendable () -> Void)?>(nil)

    /// Sets what runs when the watch app opens and asks for a re-check; it should send the result.
    func onWatchCheck(_ action: @escaping @MainActor @Sendable () -> Void) {
        onCheck.withLock { $0 = action }
    }

    /// Starts the session; the latest state goes out once it is active.
    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Sends the snapshot the widgets read, with the wardrobe, bedtime and what the home card plays, when a
    /// watch app is installed.
    /// - Parameter play: what the home card plays next; `nil` sends the last one given.
    func send(_ play: WatchPlay? = nil) {
        if let play { played.withLock { $0 = play } }
        let play = played.withLock { $0 }
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        guard let url = AppGroup.container.snapshotURL, let snapshot = WidgetSnapshot.read(from: url) else { return }
        let persona = Persona.stored(in: AppGroup.defaults)
        let payload = WatchPayload(
            snapshot: snapshot,
            wardrobe: Wardrobe.stored(in: AppGroup.defaults, persona: persona),
            bedtime: BedtimeSchedule.stored(in: AppGroup.defaults),
            persona: persona,
            scenes: play.scenes,
            event: play.event
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

    // This message launches the app in the background when it isn't running.
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        replyHandler([:])
        guard message[WatchPayload.checkKey] != nil, let action = onCheck.withLock({ $0 }) else { return }
        Task { @MainActor in action() }
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

/// What the home card plays, as the app last worked it out.
struct WatchPlay: Sendable {
    var scenes: [TimedScene] = []
    var event: CompanionEvent?
}
