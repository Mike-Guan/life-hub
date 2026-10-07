import Foundation

// Issue #210. The commute is only the trip between home and the office. Places start and end it; the
// clock never does, and motion only says how Mike is moving. Motion stays on the iPhone.
/// Mike on the way between home and the office.
public struct CommutePhase: Codable, Equatable, Sendable {
    public enum Leg: String, Codable, Sendable {
        /// From home on a work day.
        case toWork
        /// From the office once work is over.
        case home
    }

    public enum Stage: String, Codable, Sendable {
        case walking
        /// On a train, bus or car.
        case onTransit
        /// Just arrived at the other end; `since` is the arrival, so it plays once.
        case arrived
    }

    public var leg: Leg
    public var stage: Stage
    /// When this stage started.
    public var since: Date

    public init(leg: Leg, stage: Stage, since: Date) {
        self.leg = leg
        self.stage = stage
        self.since = since
    }
}

/// What the motion coprocessor saw from `start`, reduced to what the commute needs.
public struct MotionSample: Equatable, Sendable {
    public enum Kind: Sendable {
        case walking
        case transit
        /// Still, or the coprocessor isn't sure.
        case unclear
    }

    public var kind: Kind
    public var start: Date

    public init(kind: Kind, start: Date) {
        self.kind = kind
        self.start = start
    }
}

/// Rules for the commute.
public enum CommuteEngine {
    /// After this long without arriving anywhere, the trip is no longer a commute.
    public static let longest: TimeInterval = 2 * 60 * 60
    /// How long the arrival shows after reaching the other end.
    public static let arrivedLasts: TimeInterval = 3 * 60

    /// The commute at `now`.
    /// - Parameters:
    ///   - mode: the current mode; leaving the office is the way home only when it isn't work (lunch keeps 上班).
    ///   - motion: samples from the iPhone, any order; walking is assumed when they can't tell.
    /// - Returns: `nil` when Mike isn't between home and the office.
    public static func phase(
        presence: PlacePresence,
        mode: Mode?,
        motion: [MotionSample],
        now: Date,
        work: ModeRules = .standard,
        calendar: Calendar = .current
    ) -> CommutePhase? {
        if let arrived = arrival(presence: presence, mode: mode, now: now, work: work, calendar: calendar) {
            return arrived
        }
        let leaves = [HubPlace.Kind.home, .office].compactMap { kind in presence.left(kind).map { (kind, $0) } }
        guard let latest = leaves.max(by: { $0.1 < $1.1 }) else { return nil }
        let (from, left) = latest
        guard now >= left, now < left.addingTimeInterval(longest), presence.since(from) == nil else { return nil }
        // A leave right after arriving was a pass-by, as for the walk.
        if let stay = presence.lastArrivals[from.rawValue], left.timeIntervalSince(stay) < PlacePresence.bounce {
            return nil
        }
        // Arriving anywhere since ends the trip.
        guard !presence.arrivals.values.contains(where: { $0 >= left && $0 <= now }) else { return nil }
        let leg: CommutePhase.Leg
        switch from {
        case .home:
            guard work.workdays.contains(calendar.component(.weekday, from: left)) else { return nil }
            leg = .toWork
        default:
            guard mode != .work else { return nil }
            leg = .home
        }
        let moving = motion.filter { $0.kind != .unclear && $0.start >= left && $0.start <= now }
            .sorted { $0.start < $1.start }
        guard let last = moving.last else { return CommutePhase(leg: leg, stage: .walking, since: left) }
        if last.kind == .transit { return CommutePhase(leg: leg, stage: .onTransit, since: last.start) }
        // Walking again after the train starts a new walking stage.
        let rode = moving.contains { $0.kind == .transit }
        return CommutePhase(leg: leg, stage: .walking, since: rode ? last.start : left)
    }

    // Arriving at the office after leaving home on a work day, or at home after leaving the office.
    private static func arrival(
        presence: PlacePresence,
        mode: Mode?,
        now: Date,
        work: ModeRules,
        calendar: Calendar
    ) -> CommutePhase? {
        let trips: [(to: HubPlace.Kind, from: HubPlace.Kind, leg: CommutePhase.Leg)] = [
            (.office, .home, .toWork), (.home, .office, .home),
        ]
        for trip in trips {
            guard let at = presence.since(trip.to), now >= at, now < at.addingTimeInterval(arrivedLasts),
                let left = presence.left(trip.from), left <= at, at.timeIntervalSince(left) < longest
            else { continue }
            switch trip.leg {
            case .toWork: guard work.workdays.contains(calendar.component(.weekday, from: left)) else { continue }
            case .home: guard mode != .work else { continue }
            }
            return CommutePhase(leg: trip.leg, stage: .arrived, since: at)
        }
        return nil
    }
}
