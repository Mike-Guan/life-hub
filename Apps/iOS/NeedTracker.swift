import Foundation
import HubCore
import Observation

/// Works out what RUNNER acts out from where Mike is, Screen Time and what HealthKit says.
@MainActor
@Observable
final class NeedTracker {
    /// The current need, `nil` when there is none.
    private(set) var reading: NeedReading?
    /// Today's invite text while its need lasts, `nil` when none went out for it.
    private(set) var invite: String?
    /// The celebration or off-work animation RUNNER should play, `nil` when there is none.
    private(set) var event: CompanionEvent?
    /// Last failure, for the UI to show.
    private(set) var lastError: String?
    @ObservationIgnored private var motion: HealthMotion.Reading?

    /// Workouts from the last HealthKit reading; empty before the first one.
    var workouts: [WorkoutSummary] { motion?.workouts ?? [] }

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

    /// Recomputes the need from the stored presence and the last HealthKit reading, and reschedules
    /// today's invite for it.
    /// - Parameter manualSince: when Mike last changed mode by hand.
    func refresh(places: PlaceSettings, manualSince: Date?, now: Date = .now) {
        let presence = PlacePresence.stored(in: AppGroup.defaults)
        let signals = NeedSignals(
            scrollThresholdAt: ScrollWatch.reachedAt,
            scrollSeenAt: ScrollWatch.seenAt,
            manualSince: manualSince,
            atHomeSince: presence.since(.home),
            homeKnown: places[.home] != nil,
            stillSince: motion?.stillSince,
            atGym: presence.since(.gym) != nil,
            workouts: motion?.workouts ?? []
        )
        reading = NeedEngine.need(signals, now: now)
        InviteReminder.plan(reading, now: now)
        invite = InviteReminder.sent(for: reading)
    }

    // Only called while the app is on screen, so a celebration isn't spent in the background.
    /// Picks the newest workout worth celebrating that hasn't been, and remembers it.
    func celebrate(bedtime: Bedtime, now: Date = .now) {
        // Without a reading the remembered ids would all look stale and be dropped.
        guard bedtime == .off, let workouts = motion?.workouts else { return }
        let recent = Set(workouts.map(\.id))
        // Ids of workouts that dropped out of the last two days are forgotten, so the list stays short.
        var celebrated = Set(AppGroup.defaults.stringArray(forKey: Self.celebratedKey) ?? []).intersection(recent)
        guard let workout = NeedEngine.celebration(workouts, celebrated: celebrated, now: now) else { return }
        celebrated.insert(workout.id)
        AppGroup.defaults.set(Array(celebrated), forKey: Self.celebratedKey)
        event = .celebrate(id: workout.id, kind: workout.kind)
    }

    /// Plays the off-work animation for the day of `date`; HAKU plays it once per day.
    func offWork(at date: Date) {
        event = .offWork(id: date.formatted(Self.day))
    }

    private static let celebratedKey = "celebratedWorkouts"
    // "yyyy-MM-dd" in local time, the id format of `CompanionEvent.offWork`.
    private static let day = Date.ISO8601FormatStyle(timeZone: .current).year().month().day()
}
