import HealthKit
import HubCore

// Issue #205. HealthKit wakes the app when a workout is saved, so the watch can cheer without the iPhone
// app being opened. As for the home card, only each workout's id, group and times leave HealthKit.
/// Calls back when HealthKit saves a new workout, also with the app in the background.
@MainActor
enum WorkoutObserver {
    private static let store = HKHealthStore()
    private static var query: HKObserverQuery?

    /// Starts watching for new workouts. Does nothing when already started or without HealthKit.
    /// - Parameter onNew: runs once per HealthKit wake-up; HealthKit waits for it before suspending the app.
    static func start(onNew: @escaping @MainActor @Sendable () async -> Void) {
        guard HKHealthStore.isHealthDataAvailable(), query == nil else { return }
        let type = HKObjectType.workoutType()
        let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
            let done = Done(call: completion)
            guard error == nil else {
                done.call()
                return
            }
            Task { @MainActor in
                // The first run comes at launch; before Mike has answered the Health sheet, the app's own
                // open asks, so permission prompts don't overlap.
                let asked = try? await store.statusForAuthorizationRequest(toShare: [], read: [.workoutType()])
                if asked == .unnecessary {
                    await onNew()
                }
                done.call()
            }
        }
        self.query = query
        store.execute(query)
        store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, error in
            guard let error else { return }
            let detail = error.localizedDescription
            Task { @MainActor in Dogfood.note("health", "运动存好后叫醒 App 没开成：\(detail)") }
        }
    }

    // HealthKit's completion block may be called from any thread.
    private struct Done: @unchecked Sendable {
        let call: () -> Void
    }
}
