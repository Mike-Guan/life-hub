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

/// Turns acceleration samples into shakes: three hard jolts within a second, then a pause.
struct ShakeDetector: Sendable {
    /// Acceleration a jolt must reach, in g, gravity excluded.
    static let threshold = 1.4
    /// Jolts that make a shake.
    static let jolts = 3
    /// Time the jolts of one shake fall within, in seconds.
    static let window: TimeInterval = 1
    /// A strong sample this long after the previous one starts a new jolt even without a dip between, in seconds.
    static let joltGap: TimeInterval = 0.15
    /// Time after a shake before the next one counts, in seconds.
    static let cooldown: TimeInterval = 1.5

    private var joltStarts: [TimeInterval] = []
    private var lastStrong = -TimeInterval.infinity
    private var dipped = true
    private var lastShake = -TimeInterval.infinity

    /// Adds a sample.
    /// - Parameters:
    ///   - magnitude: acceleration in g, gravity excluded.
    ///   - time: when it was measured, in seconds.
    /// - Returns: true when the sample completes a shake.
    mutating func add(magnitude: Double, at time: TimeInterval) -> Bool {
        guard magnitude >= Self.threshold else {
            dipped = true
            return false
        }
        guard time - lastShake >= Self.cooldown else { return false }
        // A jolt lasts one or more samples; the watch delivers only about 17 a second. A new jolt starts after the
        // reading drops below the threshold, so three are needed and one punch (a push and a stop) is not a shake.
        let newJolt = dipped || time - lastStrong > Self.joltGap
        lastStrong = time
        dipped = false
        guard newJolt else { return false }
        joltStarts = joltStarts.filter { time - $0 < Self.window } + [time]
        guard joltStarts.count >= Self.jolts else { return false }
        lastShake = time
        joltStarts = []
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
