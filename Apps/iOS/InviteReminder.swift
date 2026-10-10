import Foundation
import HubCore
import UserNotifications

// The one push a day (L2 in CLAUDE.md). Scheduled for when the need has lasted long enough, and
// dropped again when a later refresh finds the need gone. Shared with the Screen Time extension.
/// Schedules today's invite notification.
enum InviteReminder {
    /// Category the notification content extension draws RUNNER for.
    static let category = "invite"
    /// Category of the scrolling-at-work notice, which has no 走 button.
    static let workCategory = "inviteWork"
    /// Key in the notification's `userInfo` for the need's raw value.
    static let needKey = "need"
    static let requestID = "invite"
    /// The invite's 走 button, which starts the walk to the gym.
    static let goAction = "go"

    /// Replaces the scheduled invite with one for `reading`, or removes it when there should be none.
    /// - Parameter signals: what the app knows now, to judge whether the last invite was followed.
    static func plan(_ reading: NeedReading?, signals: NeedSignals? = nil, now: Date = .now) {
        let defaults = AppGroup.defaults
        var log = InviteLog.stored(in: defaults).settled(now: now)
        let backoff = judgeLastInvite(log, signals: signals, now: now)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        let wasPending = log.pendingNeed != nil
        log.pendingAt = nil
        log.pendingNeed = nil
        let bedtime = BedtimeSchedule.stored(in: defaults)
        let energy = EnergyLog.read(from: AppGroup.container.energyLogURL)
        let rules = AppGroup.needRules(now: now)
        let at = NeedEngine.inviteTime(
            for: reading,
            now: now,
            lastInviteAt: log.lastSentAt,
            bedtime: bedtime,
            sleptShort: StateEngine.sleptShort(events: energy.events, now: now),
            rules: rules
        )
        let paused = reading.flatMap { reading in at.map { backoff.isPaused(reading.need, at: $0) } } ?? false
        if let reading, let at, !paused {
            let content = UNMutableNotificationContent()
            content.title = rules.persona.title
            content.body = NeedEngine.inviteText(
                for: reading.need,
                taskSoon: taskSoon(after: at),
                persona: rules.persona
            )
            content.sound = .default
            // Work-time notices have no 走 button.
            let atWork = reading.need == .slacking || reading.need == .sitting
            content.categoryIdentifier = atWork ? workCategory : category
            content.userInfo = [needKey: reading.need.rawValue]
            let delay = max(at.timeIntervalSince(now), 1)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            // The completion handler form, so the Screen Time extension doesn't have to wait for it.
            let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
            log.pendingAt = at
            log.pendingNeed = reading.need
        }
        log.store(in: defaults)
        if reading != nil || wasPending {
            notePlan(reading, at: log.pendingAt, paused: paused, now: now)
        }
    }

    // Issue #129: the plan and the plans to send nothing, once per change.
    /// Adds the invite plan to the decision log.
    private static func notePlan(_ reading: NeedReading?, at: Date?, paused: Bool, now: Date) {
        let deviceID = HubDevice.id(defaults: AppGroup.defaults)
        var signals = [DecisionLog.subjectKey: "invite", "hour": String(Calendar.current.component(.hour, from: now))]
        signals["need"] = reading?.need.rawValue
        if paused { signals["paused"] = "yes" }
        let action = at == nil ? Decision.noAction : reading?.need.rawValue ?? Decision.noAction
        let decision = Decision(kind: .push, action: action, target: at, signals: signals, at: now, deviceID: deviceID)
        DecisionLog.update(at: AppGroup.container.decisionLogURL, now: now) { $0.appendIfChanged(decision) }
    }

    // Each sent invite is judged once, as soon as the signals can tell.
    /// Records whether the last invite was followed, and returns the back-off state.
    private static func judgeLastInvite(_ log: InviteLog, signals: NeedSignals?, now: Date) -> NudgeBackoff {
        let defaults = AppGroup.defaults
        var backoff = NudgeBackoff.stored(in: defaults)
        guard let signals, let sent = log.lastSentAt, let need = log.lastNeed, backoff.judgedSentAt != sent else {
            return backoff
        }
        let departed = GymDeparture.stored(in: defaults)?.at
        let followed = NudgeBackoff.followed(need, sentAt: sent, signals: signals, departedAt: departed, now: now)
        guard let followed else { return backoff }
        let wasPaused = backoff.isPaused(need, at: now)
        backoff.record(need, followed: followed, sentAt: sent, now: now)
        backoff.store(in: defaults)
        let deviceID = HubDevice.id(defaults: defaults)
        let pauses = !wasPaused && backoff.isPaused(need, at: now)
        noteJudged(need, followed: followed, sentAt: sent, pauses: pauses, now: now)
        if let moment = ChangeEngine.gotUp(need, followed: followed, sentAt: sent, deviceID: deviceID) {
            ChangeLog.note(moment, in: defaults)
        }
        return backoff
    }

    /// Adds the verdict on the invite sent at `sentAt` and the back-off step to the decision log.
    private static func noteJudged(_ need: CompanionNeed, followed: Bool, sentAt: Date, pauses: Bool, now: Date) {
        let deviceID = HubDevice.id(defaults: AppGroup.defaults)
        let signals = [DecisionLog.subjectKey: "backoff", "need": need.rawValue]
        let step = Decision(
            kind: .backoff,
            action: pauses ? "pause" : Decision.noAction,
            target: pauses ? now : nil,
            signals: signals,
            at: now,
            deviceID: deviceID
        )
        DecisionLog.update(at: AppGroup.container.decisionLogURL, now: now) { log in
            if let sent = log.latest(.push, action: need.rawValue, target: sentAt) {
                log.judge(sent.id, followed ? .yes : .no, by: deviceID, at: now)
            }
            log.append(step)
            return true
        }
    }

    /// The text of the invite sent for `reading`, or `nil` when none went out for it.
    static func sent(for reading: NeedReading?) -> String? {
        guard let reading, let sent = InviteLog.stored(in: AppGroup.defaults).lastSentAt else { return nil }
        guard sent >= reading.since else { return nil }
        let persona = Persona.stored(in: AppGroup.defaults)
        return NeedEngine.inviteText(for: reading.need, taskSoon: taskSoon(after: sent), persona: persona)
    }

    /// Whether a Daily task starts within the hour after `date`.
    private static func taskSoon(after date: Date) -> Bool {
        DailyPlan.stored(in: AppGroup.defaults)?.hasTask(within: DailyAgenda.inviteLead, after: date) ?? false
    }
}
