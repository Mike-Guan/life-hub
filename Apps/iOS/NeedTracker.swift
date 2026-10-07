import Foundation
import HubCore
import Observation

/// Works out what RUNNER acts out from where Mike is, Screen Time and what HealthKit says.
@MainActor
@Observable
final class NeedTracker {
    /// The current need, `nil` when there is none.
    private(set) var reading: NeedReading?
    /// Where Mike is and his recent workouts, for what HAKU does alongside him.
    private(set) var activitySignals = ActivitySignals()
    /// The last time Mike said he is going to the gym, `nil` when never.
    private(set) var departure: GymDeparture?
    /// Today's invite text while its need lasts, `nil` when none went out for it.
    private(set) var invite: String?
    /// The celebration or off-work animation RUNNER should play, `nil` when there is none.
    private(set) var event: CompanionEvent?
    /// Whether Mike sat too long or just stood up, from the last stand hours; `nil` before the first reading.
    private(set) var sit: SitState?
    /// The last Screen Time report of couch scrolling, `nil` when there was none.
    private(set) var scrollSeenAt: Date?
    /// How Mike moved since he left home or the office, while that may be the commute; empty otherwise.
    private(set) var commuteMotion: [MotionSample] = []
    /// Last failure, for the UI to show.
    private(set) var lastError: String?
    @ObservationIgnored private var motion: HealthMotion.Reading?

    /// Workouts from the last HealthKit reading; empty before the first one.
    var workouts: [WorkoutSummary] { motion?.workouts ?? [] }

    // Re-read each time the app becomes active, so workouts the Watch syncs later still count.
    /// Reads workouts and steps from HealthKit.
    func importMotion() async {
        do {
            let now = Date.now
            motion = try await HealthMotion.recent(now: now)
            // Kept for the widgets and the Screen Time extension, which can't read HealthKit.
            if let motion {
                let state = SitEngine.state(motion.standHours, now: now)
                sit = state
                state.store(in: AppGroup.defaults)
            }
            lastError = nil
        } catch {
            lastError = "读不到健康 App 里的运动和步数：\(error.localizedDescription)"
        }
    }

    // Asked only after leaving home or the office, so the motion coprocessor is read once per event, not watched.
    /// Reads how Mike moved since the latest leave from home or the office, within the commute's limit.
    func importCommuteMotion(now: Date = .now) async {
        let presence = PlacePresence.stored(in: AppGroup.defaults)
        let leaves = [HubPlace.Kind.home, .office].compactMap { presence.since($0) == nil ? presence.left($0) : nil }
        guard let left = leaves.max(), now.timeIntervalSince(left) < CommuteEngine.longest else {
            commuteMotion = []
            return
        }
        do {
            commuteMotion = try await CommuteMotion.samples(from: left, to: now)
        } catch is CommuteMotion.NotAuthorized {
            commuteMotion = []
            lastError = "没开「运动与健身」权限：通勤路上 HAKU 只会走路。可以在设置 > 隐私与安全性里打开。"
        } catch {
            commuteMotion = []
            lastError = "读不到通勤路上的运动状态：\(error.localizedDescription)"
        }
    }

    /// Recomputes the need from the stored presence and the last HealthKit reading, and reschedules
    /// today's invite for it.
    /// - Parameters:
    ///   - manualSince: when Mike last changed mode by hand.
    ///   - mode: the current mode.
    func refresh(places: PlaceSettings, manualSince: Date?, mode: Mode?, now: Date = .now) {
        let presence = PlacePresence.stored(in: AppGroup.defaults)
        departure = GymDeparture.stored(in: AppGroup.defaults)
        let signals = NeedSignals(
            scrollThresholdAt: ScrollWatch.reachedAt,
            scrollSeenAt: ScrollWatch.seenAt,
            manualSince: manualSince,
            atHomeSince: presence.since(.home),
            homeKnown: places[.home] != nil,
            stillSince: motion?.stillSince,
            atGym: presence.since(.gym) != nil,
            workouts: motion?.workouts ?? [],
            fitnessSeenAt: presence.since(.fitness) ?? presence.left(.fitness),
            departing: departure?.isActive(at: now, presence: presence) ?? false,
            slackThresholdAt: ScrollWatch.workReachedAt,
            slackSeenAt: ScrollWatch.workSeenAt,
            sit: sit,
            mode: mode
        )
        let days = AppGroup.activityDays(now: now)
        reading = NeedEngine.need(
            signals,
            now: now,
            rules: AppGroup.needRules(now: now),
            days: days,
            work: .stored(in: AppGroup.defaults)
        )
        activitySignals = ActivitySignals(presence: presence, workouts: motion?.workouts ?? [])
        scrollSeenAt = ScrollWatch.seenAt ?? ScrollWatch.reachedAt
        InviteReminder.plan(reading, signals: signals, now: now)
        invite = InviteReminder.sent(for: reading)
    }

    // Only called while the app is on screen, so a celebration isn't spent in the background.
    /// Picks the newest workout worth celebrating that hasn't been, and remembers it.
    func celebrate(bedtime: Bedtime, now: Date = .now) {
        guard let due = due(bedtime: bedtime, now: now) else { return }
        AppGroup.defaults.set(Array(due.celebrated.union([due.workout.id])), forKey: Self.celebratedKey)
        event = .celebrate(id: due.workout.id, kind: due.workout.kind)
    }

    // The watch cheers when HealthKit wakes the app; the iPhone home still cheers on the next open.
    /// The workout cheer due at `now`, without spending it; `nil` at bedtime or when none is due.
    func dueCelebration(bedtime: Bedtime, now: Date = .now) -> CompanionEvent? {
        due(bedtime: bedtime, now: now).map { .celebrate(id: $0.workout.id, kind: $0.workout.kind) }
    }

    private func due(bedtime: Bedtime, now: Date) -> (workout: WorkoutSummary, celebrated: Set<String>)? {
        // Without a reading the remembered ids would all look stale and be dropped.
        guard bedtime == .off, let workouts = motion?.workouts else { return nil }
        let recent = Set(workouts.map(\.id))
        // Ids of workouts that dropped out of the last two days are forgotten, so the list stays short.
        let celebrated = Set(AppGroup.defaults.stringArray(forKey: Self.celebratedKey) ?? []).intersection(recent)
        guard let workout = NeedEngine.celebration(workouts, celebrated: celebrated, now: now) else { return nil }
        return (workout, celebrated)
    }

    /// Plays the off-work animation for the day of `date`; HAKU plays it once per day.
    func offWork(at date: Date) {
        event = .offWork(id: date.formatted(Self.day))
    }

    private static let celebratedKey = "celebratedWorkouts"
    // "yyyy-MM-dd" in local time, the id format of `CompanionEvent.offWork`.
    private static let day = Date.ISO8601FormatStyle(timeZone: .current).year().month().day()
}
