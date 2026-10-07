import Foundation
import HubCore
import WatchConnectivity
import WidgetKit

// The iPhone is the only writer; the watch keeps the last payload so its widgets can read it.
/// Receives HAKU's state from the iPhone and stores it for the watch app and widgets.
final class WatchReceiver: NSObject, WCSessionDelegate, @unchecked Sendable {
    // No stored state besides the session, which WatchConnectivity makes safe to use from any thread.
    static let shared = WatchReceiver()
    /// Posted after a new payload is stored.
    static let didReceive = Notification.Name("WatchReceiver.didReceive")
    /// Posted with a message for the watch app when a payload could not be stored.
    static let didFail = Notification.Name("WatchReceiver.didFail")
    /// How long a background launch waits for pending transfers.
    private static let pendingWait: Duration = .seconds(10)

    /// Starts the session.
    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Returns once the session has delivered what was pending, or after a short wait.
    func waitForPendingContent() async {
        activate()
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: Self.pendingWait)
        while WCSession.default.hasContentPending, clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        store(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        store(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        store(userInfo)
    }

    private func store(_ message: [String: Any]) {
        guard let payload = WatchPayload(message: message) else { return }
        // A write that fails leaves the last payload in place; the next one from the iPhone tries again.
        do {
            guard let url = AppGroup.container.watchPayloadURL else { throw CocoaError(.fileNoSuchFile) }
            try payload.write(to: url)
        } catch {
            post(Self.didFail, "没存下 iPhone 发来的状态：\(error.localizedDescription)")
            return
        }
        WidgetCenter.shared.reloadAllTimelines()
        post(Self.didReceive, nil)
    }

    // Delegate calls arrive on a background queue; the app's views listen on the main one.
    private func post(_ name: Notification.Name, _ message: String?) {
        DispatchQueue.main.async { NotificationCenter.default.post(name: name, object: message) }
    }
}
