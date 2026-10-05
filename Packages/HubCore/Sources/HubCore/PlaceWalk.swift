import Foundation

// Issue #141, Mike approved the preview 2026-10-05 14:46Z: HAKU walks after Mike leaves one of the four
// preset places, until he arrives somewhere or `lasts` runs out. The mode doesn't change.
/// HAKU walking after Mike left a place.
public struct PlaceWalk: Equatable, Sendable {
    /// The place Mike left: home, the office, the fitness gym or the boxing gym.
    public var from: HubPlace.Kind
    /// When he left.
    public var since: Date

    public init(from: HubPlace.Kind, since: Date) {
        self.from = from
        self.since = since
    }

    /// How long the walk lasts at most.
    public static let lasts: TimeInterval = 30 * 60

    /// When the walk ends unless Mike arrives somewhere first.
    public var until: Date { since.addingTimeInterval(Self.lasts) }

    static let places: [HubPlace.Kind] = [.home, .office, .fitness, .gym]

    // A leave right after arriving was a pass-by, and a stay that picked up again after GPS drift
    // is not a leave, so neither starts a walk.
    /// The walk at `now` from the latest leave of the four places in `presence`.
    /// - Returns: `nil` when Mike is at a place he arrived at since, or the walk ran out.
    public static func walk(in presence: PlacePresence, now: Date) -> PlaceWalk? {
        let leaves = places.compactMap { kind in presence.left(kind).map { (kind, $0) } }
        guard let latest = leaves.max(by: { $0.1 < $1.1 }) else { return nil }
        let (kind, left) = latest
        guard now >= left, now < left.addingTimeInterval(lasts), presence.since(kind) == nil else { return nil }
        if let stay = presence.lastArrivals[kind.rawValue], left.timeIntervalSince(stay) < PlacePresence.bounce {
            return nil
        }
        guard !presence.arrivals.values.contains(where: { $0 >= left && $0 <= now }) else { return nil }
        return PlaceWalk(from: kind, since: left)
    }
}
