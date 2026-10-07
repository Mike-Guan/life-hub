import CoreMotion
import HubCore

// Issue #210. Privacy rule: motion stays on this iPhone. Only walking / transit and a start time leave
// this file, and only while Mike is between home and the office.
/// Reads how Mike moved recently from the motion coprocessor, for the commute.
@MainActor
enum CommuteMotion {
    /// Thrown when Mike turned off Motion & Fitness for Life Hub.
    struct NotAuthorized: Error {}

    // Kept for the app's life so a query isn't dropped with its manager.
    private static let manager = CMMotionActivityManager()

    /// The activities from `start` to `now`, reduced to walking, transit or unclear.
    /// - Returns: empty when the device has no motion coprocessor.
    /// - Throws: `NotAuthorized` without Motion & Fitness access, or the Core Motion error.
    static func samples(from start: Date, to now: Date = .now) async throws -> [MotionSample] {
        guard CMMotionActivityManager.isActivityAvailable() else { return [] }
        guard CMMotionActivityManager.authorizationStatus() != .denied,
            CMMotionActivityManager.authorizationStatus() != .restricted
        else { throw NotAuthorized() }
        return try await withCheckedThrowingContinuation { continuation in
            // The first query shows the permission prompt.
            manager.queryActivityStarting(from: start, to: now, to: .main) { activities, error in
                if let error, (error as NSError).code == Int(CMErrorMotionActivityNotAuthorized.rawValue) {
                    continuation.resume(throwing: NotAuthorized())
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (activities ?? []).map(sample))
                }
            }
        }
    }

    nonisolated private static func sample(_ activity: CMMotionActivity) -> MotionSample {
        let kind: MotionSample.Kind =
            if activity.confidence == .low {
                .unclear
            } else if activity.automotive {
                .transit
            } else if activity.walking || activity.running || activity.cycling {
                .walking
            } else {
                .unclear
            }
        return MotionSample(kind: kind, start: activity.startDate)
    }
}
