import Foundation

// The home shows one event at a time and this slot comes first, so an event that stayed would hide later
// stand-ups, revivals and finished tasks until the app restarts. RUNNER remembers what it played, so
// clearing the slot never replays anything.
/// The one-off event the app hands RUNNER, cleared once its animation is over.
public struct EventSlot: Equatable, Sendable {
    /// The event to play, `nil` when there is none.
    public private(set) var event: CompanionEvent?
    /// When `event` was raised, `nil` when there is none.
    public private(set) var raisedAt: Date?

    /// How long an event stays: longer than the longest one-off animation (the 6 s stretch).
    public static let hold: TimeInterval = 30

    public init() {}

    /// Puts `event` in the slot from `now`, replacing any earlier one.
    public mutating func raise(_ event: CompanionEvent, at now: Date) {
        self.event = event
        raisedAt = now
    }

    /// Empties the slot once its event has been there for `hold`.
    /// - Returns: `true` when the slot was emptied.
    @discardableResult
    public mutating func expire(at now: Date) -> Bool {
        guard let raisedAt, now.timeIntervalSince(raisedAt) >= Self.hold else { return false }
        event = nil
        self.raisedAt = nil
        return true
    }
}
