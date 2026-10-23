import Foundation

// 2026-10-23: with the app closed, arrivals were applied only once it was opened (all modes). Each
// launch, the background one a geofence causes included, now replays the last state of every fence;
// whatever the presence already shows is skipped, so each event is applied once.
/// One geofence report: Mike entered or left `place` at `date`.
public struct PlaceEvent: Equatable, Sendable {
    public var place: HubPlace
    public var entered: Bool
    public var date: Date

    public init(place: HubPlace, entered: Bool, date: Date) {
        self.place = place
        self.entered = entered
        self.date = date
    }

    /// `true` when `presence` already shows this arrival or departure.
    public func isKnown(in presence: PlacePresence) -> Bool {
        (presence.since(key: place.id) != nil) == entered
    }

    /// What applying the event did.
    public struct Applied: Equatable, Sendable {
        /// The presence before the event.
        public var before: PlacePresence
        /// The presence after it, to store.
        public var after: PlacePresence
        /// The mode change made, or `nil` when the mode stays.
        public var decision: ModeDecision?
    }

    /// Records the event in `presence` and switches the mode in `store` as the place rules say.
    /// - Parameters:
    ///   - presence: where Mike is as last stored.
    ///   - now: when the event is handled; later than `date` when it's caught up at a launch.
    /// - Returns: `nil` when `presence` already shows the event, so nothing changed.
    @MainActor
    public func apply(
        to presence: PlacePresence,
        store: ModeStore,
        rules: ModeRules,
        cards: ModeCards,
        persona: Persona,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Applied? {
        guard !isKnown(in: presence) else { return nil }
        let stayStart = presence.since(place)
        var after = presence
        after.record(place, entered: entered, at: date)
        // Manual wins: a mode chosen after Mike moved stays.
        let changedSince = store.log.active.last.map { $0.at > date } ?? false
        var decision: ModeDecision?
        if !changedSince {
            if !entered, let stayStart, date.timeIntervalSince(stayStart) < PlacePresence.bounce {
                // Walking past a fence takes back the switch the arrival made.
                decision = store.autoSwitch(.passedBy(arrivedAt: stayStart), rules: rules, now: now, calendar: calendar)
            } else if let trigger = place.trigger(entered: entered) {
                decision = store.autoSwitch(
                    trigger, rules: rules, cards: cards, persona: persona, now: now, calendar: calendar
                )
            }
        }
        // Place comes first: a leave that was held still ends work at the next place event.
        let made = decision ?? store.settle(presence: after, now: now, calendar: calendar)
        return Applied(before: presence, after: after, decision: made)
    }
}
