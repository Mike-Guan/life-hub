import HealthKit
import HubCore

// Privacy rule: raw samples stay in HealthKit. Only each night's total leaves this file.
/// Reads sleep from HealthKit.
enum HealthSleep {
    /// Asks for read access (HealthKit shows the sheet once), then reads the night for `now`.
    /// - Returns: `nil` when HealthKit is unavailable, access was denied or there is no sleep yet.
    /// - Throws: HealthKit errors.
    static func lastNight(now: Date = .now) async throws -> SleepNight? {
        let intervals = try await asleep(in: SleepNight.window(for: now))
        return intervals.flatMap { SleepNight.from($0, now: now) }
    }

    /// Reads one night per hub day from `start` to `end`, for the return replay.
    /// - Returns: no nights when HealthKit is unavailable or access was denied.
    /// - Throws: HealthKit errors.
    static func nights(from start: Date, to end: Date) async throws -> [SleepNight] {
        let intervals = try await asleep(in: SleepNight.window(from: start, to: end))
        return intervals.map { SleepNight.nights($0, from: start, to: end) } ?? []
    }

    /// The asleep intervals in `window`, or `nil` when HealthKit is unavailable.
    private static func asleep(in window: DateInterval) async throws -> [SleepInterval]? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let store = HKHealthStore()
        let type = HKCategoryType(.sleepAnalysis)
        try await store.requestAuthorization(toShare: [], read: [type])

        let predicate = HKQuery.predicateForSamples(withStart: window.start, end: window.end)
        let query = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: []
        )
        var intervals: [SleepInterval] = []
        for sample in try await query.result(for: store) {
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value),
                HKCategoryValueSleepAnalysis.allAsleepValues.contains(value)
            else { continue }
            intervals.append(SleepInterval(start: sample.startDate, end: sample.endDate))
        }
        return intervals
    }
}
