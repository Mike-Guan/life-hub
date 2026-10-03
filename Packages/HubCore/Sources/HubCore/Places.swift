import Foundation

/// A place Mike can be at: the gym and office switch the mode, home tells needs he is home.
/// Stored only on the device.
public struct HubPlace: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case gym
        case office
        case home

        public var title: String {
            switch self {
            case .gym: "拳馆"
            case .office: "公司"
            case .home: "家"
            }
        }

        /// The trigger for arriving (`entered`) or leaving.
        public func trigger(entered: Bool) -> ModeTrigger? {
            switch self {
            case .gym: entered ? .enteredGym : .leftGym
            case .office: entered ? .enteredOffice : nil
            case .home: nil
            }
        }
    }

    /// About 100 m, the geofence size in the plan (Issue #4).
    public static let defaultRadius: Double = 100

    public var kind: Kind
    public var latitude: Double
    public var longitude: Double
    /// Meters.
    public var radius: Double

    public init(kind: Kind, latitude: Double, longitude: Double, radius: Double = defaultRadius) {
        self.kind = kind
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
    }
}

// Privacy rule: places live in the App Group's user defaults, never in the repo or on a network.
/// The places Mike has set.
public struct PlaceSettings: Codable, Equatable, Sendable {
    static let defaultsKey = "places"

    public var places: [HubPlace]

    public init(places: [HubPlace] = []) {
        self.places = places
    }

    /// The place of `kind`, if set. Setting `nil` removes it.
    public subscript(kind: HubPlace.Kind) -> HubPlace? {
        get { places.first { $0.kind == kind } }
        set {
            places.removeAll { $0.kind == kind }
            if let newValue { places.append(newValue) }
        }
    }

    /// The settings saved in `defaults`, or none when nothing is saved or it can't be read.
    public static func stored(in defaults: UserDefaults) -> PlaceSettings {
        guard let data = defaults.data(forKey: defaultsKey) else { return PlaceSettings() }
        return (try? JSONDecoder().decode(PlaceSettings.self, from: data)) ?? PlaceSettings()
    }

    /// Saves the settings in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }
}

/// Where Mike is now, from geofence arrivals and departures. Stored only on the device.
public struct PlacePresence: Codable, Equatable, Sendable {
    static let defaultsKey = "presence"

    // Keyed by `HubPlace.Kind` raw value, so a kind this build doesn't know is kept, not fatal.
    /// When Mike arrived at each place he is at now.
    public var arrivals: [String: Date]

    public init(arrivals: [String: Date] = [:]) {
        self.arrivals = arrivals
    }

    /// When Mike arrived at `kind`, or `nil` when he isn't there.
    public func since(_ kind: HubPlace.Kind) -> Date? {
        arrivals[kind.rawValue]
    }

    /// Records arriving at (`entered`) or leaving `kind` at `date`. Repeated arrivals keep the first.
    public mutating func record(_ kind: HubPlace.Kind, entered: Bool, at date: Date) {
        if entered {
            arrivals[kind.rawValue] = arrivals[kind.rawValue] ?? date
        } else {
            arrivals[kind.rawValue] = nil
        }
    }

    /// The presence saved in `defaults`, or none when nothing is saved or it can't be read.
    public static func stored(in defaults: UserDefaults) -> PlacePresence {
        guard let data = defaults.data(forKey: defaultsKey) else { return PlacePresence() }
        return (try? JSONDecoder().decode(PlacePresence.self, from: data)) ?? PlacePresence()
    }

    /// Saves the presence in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }
}
