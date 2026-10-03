import HealthKit
import HubCore

// Privacy rule: raw samples stay in HealthKit. Only the night's total leaves this file.
/// Reads last night's sleep from HealthKit.
enum HealthSleep {
    /// Asks for read access (HealthKit shows the sheet once), then reads the night for `now`.
    /// - Returns: `nil` when HealthKit is unavailable, access was denied or there is no sleep yet.
    /// - Throws: HealthKit errors.
    static func lastNight(now: Date = .now) async throws -> SleepNight? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let store = HKHealthStore()
        let type = HKCategoryType(.sleepAnalysis)
        try await store.requestAuthorization(toShare: [], read: [type])

        let window = SleepNight.window(for: now)
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
        return SleepNight.from(intervals, now: now)
    }
}
