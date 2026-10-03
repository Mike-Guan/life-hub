import Foundation
import HubCore
import Observation

/// Works out what RUNNER acts out from where Mike is and what HealthKit says.
@MainActor
@Observable
final class NeedTracker {
    /// The current need, `nil` when there is none.
    private(set) var reading: NeedReading?
    /// Last failure, for the UI to show.
    private(set) var lastError: String?
    @ObservationIgnored private var motion: HealthMotion.Reading?

    // Re-read each time the app becomes active, so workouts the Watch syncs later still count.
    /// Reads workouts and steps from HealthKit.
    func importMotion() async {
        do {
            motion = try await HealthMotion.recent()
            lastError = nil
        } catch {
            lastError = "读不到健康 App 里的运动和步数：\(error.localizedDescription)"
        }
    }

    /// Recomputes the need from the stored presence and the last HealthKit reading.
    func refresh(places: PlaceSettings, now: Date = .now) {
        let presence = PlacePresence.stored(in: AppGroup.defaults)
        let signals = NeedSignals(
            atHomeSince: presence.since(.home),
            homeKnown: places[.home] != nil,
            stillSince: motion?.stillSince,
            atGym: presence.since(.gym) != nil,
            workouts: motion?.workouts ?? []
        )
        reading = NeedEngine.need(signals, now: now)
    }
}
