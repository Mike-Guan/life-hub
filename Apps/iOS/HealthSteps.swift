import CoreMotion
import HealthKit
import HubCore

// Issue #356 (奖励数值表 §2a). Privacy rule: step counts stay in this file. Only the steps wins leave it,
// dated at the day, never the counts.
/// Reads daily step totals for the steps win.
@MainActor
enum HealthSteps {
    /// Days read back, today included, so a day counts without opening the app that day.
    static let days = 7

    // Kept for the app's life so a query isn't dropped with its manager.
    private static let pedometer = CMPedometer()

    /// The steps wins of the last `days` calendar days: from HealthKit, which merges iPhone and watch and
    /// leaves out steps typed in by hand, or from the iPhone's pedometer when HealthKit has no steps and
    /// Motion & Fitness access is already granted.
    /// - Returns: empty when neither source has steps.
    /// - Throws: HealthKit errors.
    static func wins(now: Date = .now) async throws -> [EarnedWin] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: 1 - days, to: today) ?? today
        var totals = try await healthKit(from: start, to: now)
        if totals.isEmpty { totals = await pedometerTotals(from: start, to: now, calendar: calendar) }
        return totals.compactMap { day, steps in Win.steps(steps, on: day, now: now, calendar: calendar) }
    }

    // The same access `HealthMotion.recent` asks for, so no new prompt. No step data at all looks the
    // same as denied access, so both give an empty result.
    private static func healthKit(from start: Date, to now: Date) async throws -> [Date: Double] {
        guard HKHealthStore.isHealthDataAvailable() else { return [:] }
        let store = HKHealthStore()
        let type = HKQuantityType(.stepCount)
        try await store.requestAuthorization(toShare: [], read: [type])
        let notTyped = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyWasUserEntered, operatorType: .notEqualTo, value: true)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: start, end: now), notTyped,
        ])
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        var totals: [Date: Double] = [:]
        for day in try await query.result(for: store).statistics() {
            if let sum = day.sumQuantity() { totals[day.startDate] = sum.doubleValue(for: .count()) }
        }
        return totals
    }

    // Asks nothing: only used when Motion & Fitness is already allowed (the commute asks for it).
    private static func pedometerTotals(from start: Date, to now: Date, calendar: Calendar) async -> [Date: Double] {
        guard CMPedometer.isStepCountingAvailable(), CMPedometer.authorizationStatus() == .authorized else {
            return [:]
        }
        var totals: [Date: Double] = [:]
        var day = start
        while day < now {
            let end = min(calendar.date(byAdding: .day, value: 1, to: day) ?? now, now)
            if let steps = await pedometerSteps(from: day, to: end) { totals[day] = steps }
            day = end
        }
        return totals
    }

    private static func pedometerSteps(from start: Date, to end: Date) async -> Double? {
        await withCheckedContinuation { continuation in
            // Core Motion answers on its own queue, so the handler must not run on the main actor.
            pedometer.queryPedometerData(from: start, to: end) { @Sendable data, _ in
                continuation.resume(returning: data?.numberOfSteps.doubleValue)
            }
        }
    }
}
