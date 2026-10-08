import Foundation
import HubCore

// Mike 2026-10-07: shaking the phone or the watch makes HAKU react, the same on both. Play only: a shake never
// switches the mode, gives cans or counts anything.
/// HAKU's reaction to the phone or the watch being shaken.
enum ShakeReaction: Sendable, Equatable, CaseIterable {
    /// Swirl eyes and stars around the head, the body wobbling.
    case dizzy
    /// Pumped up on a boxing day: a hop and a punch.
    case pumped
    /// Woken from sleep: a glare, then back to sleep.
    case woken

    /// How long one reaction plays, in seconds.
    static let duration: TimeInterval = 2.4
    /// Shakes within `window` that make HAKU turn its back.
    static let limit = 3
    /// The window for `limit`, in seconds.
    static let window: TimeInterval = 60

    /// The reaction for HAKU in `mode`; `asleep` covers bedtime and naps.
    static func pick(mode: Mode, asleep: Bool) -> ShakeReaction {
        if asleep { return .woken }
        return mode == .boxing ? .pumped : .dizzy
    }

    /// Whether `shakes` within `window` before `now` reach `limit`.
    static func isTooMany(_ shakes: [Date], now: Date) -> Bool {
        shakes.filter { now.timeIntervalSince($0) < window }.count >= limit
    }

    /// What HAKU says for this reaction in `mode`, or nil for a silent one.
    func line(for mode: Mode) -> String? {
        switch self {
        case .woken: nil
        case .pumped: "再来！"
        case .dizzy:
            switch mode {
            case .work: "……喂喂喂。"
            case .chill: "……别晃了。我要吐了。"
            case .money: "……代码全乱了。"
            case .boxing: "再来！"
            }
        }
    }
}

/// Turns acceleration samples into shakes: enough time spent hard-moving within a short window, then a pause.
struct ShakeDetector: Sendable {
    /// Acceleration that counts as hard-moving, in g, gravity excluded.
    static let threshold = 4.0
    /// The window the hard-moving time is counted in, in seconds.
    static let window: TimeInterval = 0.8
    /// Hard-moving time within `window` that makes a shake, in seconds.
    static let needed: TimeInterval = 0.2
    /// The longest gap between two samples that is counted as hard-moving time, in seconds.
    static let maxStep: TimeInterval = 0.1
    /// Calm time after a shake before the next one counts, in seconds.
    static let cooldown: TimeInterval = 1.5

    // A real shake on Mike's watch stays at 7 to 12 g for the whole round without dropping in between, so it is
    // measured as time above the threshold rather than as separate jolts. Running swings the arm at 2 to 3 g.
    private var strong: [(time: TimeInterval, length: TimeInterval)] = []
    private var lastSample: TimeInterval?
    private var lastShake = -TimeInterval.infinity

    /// Adds a sample.
    /// - Parameters:
    ///   - magnitude: acceleration in g, gravity excluded.
    ///   - time: when it was measured, in seconds.
    /// - Returns: true when the sample completes a shake.
    mutating func add(magnitude: Double, at time: TimeInterval) -> Bool {
        // A gap longer than `maxStep` (a missed update, a pause) adds nothing.
        let gap = lastSample.map { time - $0 } ?? 0
        let step = gap > 0 && gap <= Self.maxStep ? gap : 0
        lastSample = time
        strong.removeAll { time - $0.time >= Self.window }
        guard magnitude >= Self.threshold else { return false }
        // Still shaking after a shake keeps it the same shake: the cooldown starts again.
        guard time - lastShake >= Self.cooldown else {
            lastShake = time
            return false
        }
        strong.append((time, step))
        guard strong.reduce(0, { $0 + $1.length }) >= Self.needed else { return false }
        lastShake = time
        strong = []
        return true
    }
}

#if os(iOS) || os(watchOS)
import CoreMotion

/// Shakes of the phone or the watch.
enum DeviceShakes {
    /// How long a view waits after it appears before it starts listening, so launch is not slowed down.
    static let startDelay: Duration = .seconds(2)

    /// A stream that yields once per shake and stops listening when it is cancelled.
    static func stream() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let listener = Listener()
            // Everything CoreMotion does happens on the listener's queue, so the main thread never waits for it,
            // also when the app comes back from the background.
            listener.queue.addOperation {
                let manager = CMMotionManager()
                guard manager.isDeviceMotionAvailable else {
                    continuation.finish()
                    return
                }
                listener.manager = manager
                manager.deviceMotionUpdateInterval = 1.0 / 50
                manager.startDeviceMotionUpdates(to: listener.queue) { motion, _ in
                    guard let motion else { return }
                    let a = motion.userAcceleration
                    let magnitude = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
                    if listener.detector.add(magnitude: magnitude, at: motion.timestamp) {
                        continuation.yield()
                    }
                }
            }
            continuation.onTermination = { _ in
                listener.queue.addOperation { listener.manager?.stopDeviceMotionUpdates() }
            }
        }
    }

    // Only `queue` touches `manager` and `detector`, one operation at a time, so they are never shared.
    private final class Listener: @unchecked Sendable {
        var manager: CMMotionManager?
        let queue: OperationQueue = {
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1
            return queue
        }()
        var detector = ShakeDetector()
    }
}
#endif
