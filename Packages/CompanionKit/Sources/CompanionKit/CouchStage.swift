import Foundation

/// How far couch scrolling has gone: scrolling along, peeking at the gym bag, then up with the bag.
enum CouchStage: Sendable {
    /// Slumped on the couch scrolling too.
    case scrolling
    /// Still scrolling, but glancing at the gym bag by the door.
    case peeking
    /// Got up with the bag over the shoulder; today's invite is showing.
    case up

    /// How long scrolling lasts before HAKU starts peeking at the bag.
    static let peekAfter: TimeInterval = 30 * 60

    /// The stage at `now` for scrolling that started at `since`.
    /// - Parameter inviting: whether today's invite is showing, which always means `.up`.
    static func at(_ now: Date, since: Date?, inviting: Bool) -> CouchStage {
        if inviting { return .up }
        guard let since, now.timeIntervalSince(since) >= peekAfter else { return .scrolling }
        return .peeking
    }
}
