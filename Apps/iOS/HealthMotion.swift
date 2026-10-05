import HealthKit
import HubCore

// Privacy rule: raw samples stay in HealthKit. Only workout summaries, one time and today's stand hours
// (in memory, reduced to `SitState`) leave this file.
/// Reads recent workouts and steps from HealthKit for RUNNER's needs.
enum HealthMotion {
    /// What needs use from HealthKit.
    struct Reading {
        var workouts: [WorkoutSummary]
        /// Start of the current stretch without walking, within the last few hours.
        var stillSince: Date?
        /// Today's Apple Watch stand hours; empty without a Watch.
        var standHours: [StandHour] = []
    }

    /// Steps in 15 minutes that count as moving.
    static let movingSteps: Double = 30

    /// Asks for read access (HealthKit shows the sheet once), then reads workouts and steps.
    /// - Returns: `nil` when HealthKit is unavailable.
    /// - Throws: HealthKit errors.
    static func recent(now: Date = .now) async throws -> Reading? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let store = HKHealthStore()
        let steps = HKQuantityType(.stepCount)
        let stand = HKCategoryType(.appleStandHour)
        try await store.requestAuthorization(toShare: [], read: [HKObjectType.workoutType(), steps, stand])
        let recent = try await workouts(in: store, now: now)
        let still = try await stillSince(in: store, steps: steps, now: now)
        let hours = try await standHours(in: store, type: stand, now: now)
        return Reading(workouts: recent, stillSince: still, standHours: hours)
    }

    private static func standHours(
        in store: HKHealthStore,
        type: HKCategoryType,
        now: Date
    ) async throws -> [StandHour] {
        let predicate = HKQuery.predicateForSamples(withStart: StateEngine.dayStart(for: now), end: now)
        let samples = HKSamplePredicate.categorySample(type: type, predicate: predicate)
        let query = HKSampleQueryDescriptor(predicates: [samples], sortDescriptors: [])
        return try await query.result(for: store).map {
            StandHour(start: $0.startDate, stood: $0.value == HKCategoryValueAppleStandHour.stood.rawValue)
        }
    }

    private static func workouts(in store: HKHealthStore, now: Date) async throws -> [WorkoutSummary] {
        let start = now.addingTimeInterval(-2 * 24 * 60 * 60)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)
        let query = HKSampleQueryDescriptor(predicates: [.workout(predicate)], sortDescriptors: [])
        return try await query.result(for: store).map(summary)
    }

    private static func summary(_ workout: HKWorkout) -> WorkoutSummary {
        let kind: WorkoutSummary.Kind
        switch workout.workoutActivityType {
        case .boxing, .kickboxing: kind = .boxing
        case .running: kind = .running
        case .traditionalStrengthTraining, .functionalStrengthTraining: kind = .strength
        default: kind = .other
        }
        let distance = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()
        return WorkoutSummary(
            id: workout.uuid.uuidString,
            kind: kind,
            start: workout.startDate,
            end: workout.endDate,
            meters: distance?.doubleValue(for: .meter())
        )
    }

    // Steps in 15-minute buckets over the last 4 hours; still since the end of the last busy one.
    // No step data at all looks the same as denied access, so it says nothing (`nil`).
    private static func stillSince(in store: HKHealthStore, steps: HKQuantityType, now: Date) async throws -> Date? {
        let start = now.addingTimeInterval(-4 * 60 * 60)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: steps, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(minute: 15)
        )
        let buckets = try await query.result(for: store).statistics().filter { $0.sumQuantity() != nil }
        guard !buckets.isEmpty else { return nil }
        let busy = buckets.filter { ($0.sumQuantity()?.doubleValue(for: .count()) ?? 0) >= movingSteps }
        return busy.map(\.endDate).max().map { min($0, now) } ?? start
    }
}
