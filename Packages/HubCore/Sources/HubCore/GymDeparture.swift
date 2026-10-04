import Foundation

/// Mike said he is going to the gym, from the invite's 走 button or the Control.
public struct GymDeparture: Codable, Equatable, Sendable {
    /// How long HAKU walks with the bag at most.
    public static let lasts: TimeInterval = 60 * 60

    public var at: Date

    public init(at: Date) {
        self.at = at
    }

    /// When the walk ends at the latest.
    public var until: Date { at.addingTimeInterval(Self.lasts) }

    // Not going has no consequence: the walk just ends.
    /// True from `at` for `lasts`, until Mike gets to the fitness gym.
    public func isActive(at date: Date, presence: PlacePresence) -> Bool {
        guard date >= at, date < until, presence.since(.fitness) == nil else { return false }
        return (presence.left(.fitness) ?? .distantPast) < at
    }

    /// What HAKU acts out for the gym day instead of the plain gym bag: walking there after 走, else
    /// waiting at the door while the invite lasts.
    /// - Parameters:
    ///   - activity: what HAKU does alongside Mike; only the gym bag, or nothing, gives way.
    ///   - departing: whether a departure is active.
    /// - Returns: `nil` when HAKU keeps the activity.
    public static func moment(
        activity: CompanionActivity?,
        need: CompanionNeed?,
        departing: Bool
    ) -> CompanionMoment? {
        guard activity == nil || activity == .gymDay else { return nil }
        if departing { return .heading }
        return need == .gymDay ? .gymInvite : nil
    }

    static let defaultsKey = "gymDeparture"

    /// The last departure saved in `defaults`, or `nil` when there is none or it can't be read.
    public static func stored(in defaults: UserDefaults) -> GymDeparture? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(GymDeparture.self, from: data)
    }

    /// Saves the departure in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }
}
