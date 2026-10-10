import Foundation
import HubCore
import Synchronization
import WatchConnectivity
import WidgetKit

// The iPhone is the only writer; the watch keeps the last payload so its widgets can read it.
/// Receives HAKU's state from the iPhone and stores it for the watch app and widgets.
final class WatchReceiver: NSObject, WCSessionDelegate, @unchecked Sendable {
    // Besides the session, which WatchConnectivity makes safe to use from any thread, only whether an ask
    // waits for activation and when the last one went, behind locks.
    static let shared = WatchReceiver()
    private let askPending = Mutex(false)
    private let lastAsk = Mutex<ContinuousClock.Instant?>(nil)
    // Raising the wrist again and again sends one ask.
    /// The shortest time between two asks.
    private static let askGap: Duration = .seconds(300)
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

    // The iPhone only re-checks the mode at a place event or when its app opens. A message from the watch
    // wakes the iPhone app in the background, so opening the watch app is a check too.
    /// Asks the iPhone to re-check the mode and send the result; sent once the session is active.
    func askPhoneToCheck() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            askPending.withLock { $0 = true }
            return
        }
        // Not reachable means the iPhone is away; the watch keeps showing the last payload.
        guard session.isReachable else { return }
        let now = ContinuousClock.now
        let due = lastAsk.withLock { last in
            guard last.map({ now - $0 >= Self.askGap }) ?? true else { return false }
            last = now
            return true
        }
        guard due else { return }
        session.sendMessage([WatchPayload.checkKey: true], replyHandler: { _ in }, errorHandler: { _ in })
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        store(session.receivedApplicationContext)
        let ask = askPending.withLock { pending in
            defer { pending = false }
            return pending
        }
        if ask { askPhoneToCheck() }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        store(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        store(userInfo)
    }

    // Sent by the iPhone while the watch app is open, so a change shows without waiting for the context.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        store(message)
    }

    private func store(_ message: [String: Any]) {
        guard let payload = WatchPayload(message: message) else { return }
        // Application context and complication transfers can arrive out of order; an older one is dropped.
        let stored = WatchPayload.read(from: AppGroup.container.watchPayloadURL)
        guard payload.replaces(stored) else { return }
        // A write that fails leaves the last payload in place; the next one from the iPhone tries again.
        do {
            guard let url = AppGroup.container.watchPayloadURL else { throw CocoaError(.fileNoSuchFile) }
            try payload.write(to: url)
        } catch {
            post(Self.didFail, "没存下 iPhone 发来的状态：\(error.localizedDescription)")
            return
        }
        // Widget reloads have a daily budget, and the iPhone now also sends while the app is open.
        if stored.map({ !payload.drawsLike($0) }) ?? true { WidgetCenter.shared.reloadAllTimelines() }
        post(Self.didReceive, nil)
    }

    // Delegate calls arrive on a background queue; the app's views listen on the main one.
    private func post(_ name: Notification.Name, _ message: String?) {
        DispatchQueue.main.async { NotificationCenter.default.post(name: name, object: message) }
    }
}
