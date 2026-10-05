import Foundation

/// A place Mike can be at: presets for home, the office and the two gyms, plus places he adds.
/// Stored only on the device.
public struct HubPlace: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case gym
        case office
        case home
        case fitness
        /// A place Mike added himself.
        case custom

        /// The places every list starts with, in the order Settings shows them.
        public static let presets: [Kind] = [.home, .office, .fitness, .gym]

        public var title: String {
            switch self {
            case .gym: "拳馆"
            case .office: "公司"
            case .home: "家"
            case .fitness: "健身房"
            case .custom: "地点"
            }
        }

        /// What arriving at a place of this kind does.
        public var action: Action {
            switch self {
            case .gym: .boxing
            case .office: .work
            case .fitness: .fitness
            case .home, .custom: .recordOnly
            }
        }

        /// The trigger for arriving (`entered`) or leaving.
        public func trigger(entered: Bool) -> ModeTrigger? {
            switch self {
            case .gym: entered ? .enteredGym : .leftGym
            case .office: entered ? .enteredOffice : .leftOffice
            case .home, .fitness, .custom: nil
            }
        }
    }

    /// What HAKU does when Mike arrives.
    public enum Action: String, Codable, CaseIterable, Sendable {
        /// Only notes that Mike is there.
        case recordOnly
        case work
        case chill
        /// Counts as the fitness gym: HAKU lifts, and a long enough visit earns the gym can.
        case fitness
        /// Counts as the boxing gym: switches straight to boxing.
        case boxing
        /// Switches to the side-hustle mode.
        case sideHustle

        public var title: String {
            switch self {
            case .recordOnly: "只记录，不切换"
            case .work: "切到上班"
            case .chill: "切到下班"
            case .fitness: "当健身房"
            case .boxing: "当拳馆"
            case .sideHustle: "切到副业"
            }
        }
    }

    /// About 100 m, the geofence size in the plan (Issue #4).
    public static let defaultRadius: Double = 100

    public var kind: Kind
    /// The preset's kind for presets, a generated id for added places. Also the geofence id.
    public var id: String
    /// Mike's name for an added place, `nil` for presets.
    public var name: String?
    /// What arriving does; presets always do what their kind does.
    public var action: Action
    public var latitude: Double
    public var longitude: Double
    /// Meters.
    public var radius: Double

    /// A preset place of `kind`.
    public init(kind: Kind, latitude: Double, longitude: Double, radius: Double = defaultRadius) {
        self.kind = kind
        self.id = kind.rawValue
        self.name = nil
        self.action = kind.action
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
    }

    /// A place Mike added.
    public static func custom(
        name: String,
        action: Action,
        latitude: Double,
        longitude: Double,
        radius: Double = defaultRadius,
        id: String = "custom" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    ) -> HubPlace {
        var place = HubPlace(kind: .custom, latitude: latitude, longitude: longitude, radius: radius)
        place.id = id
        place.name = name
        place.action = action
        return place
    }

    private enum CodingKeys: String, CodingKey { case kind, id, name, action, latitude, longitude, radius }

    /// Decodes a place; places saved before added places existed have no id, name or action.
    /// - Throws: `DecodingError` when a field is missing or has the wrong type.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        kind = try values.decode(Kind.self, forKey: .kind)
        id = try values.decodeIfPresent(String.self, forKey: .id) ?? kind.rawValue
        name = try values.decodeIfPresent(String.self, forKey: .name)
        action = try values.decodeIfPresent(Action.self, forKey: .action) ?? kind.action
        latitude = try values.decode(Double.self, forKey: .latitude)
        longitude = try values.decode(Double.self, forKey: .longitude)
        radius = try values.decodeIfPresent(Double.self, forKey: .radius) ?? Self.defaultRadius
    }

    /// The name shown in Settings.
    public var title: String { name ?? kind.title }

    // An added gym counts as the preset gym, so activities, needs and cans work the same there.
    /// The presence keys an arrival here sets: its id, plus the preset it acts as.
    public var presenceKeys: [String] {
        let acting: Kind? =
            switch action {
            case .fitness: .fitness
            case .boxing: .gym
            default: nil
            }
        guard let acting, acting.rawValue != id else { return [id] }
        return [id, acting.rawValue]
    }

    /// The trigger for arriving (`entered`) or leaving.
    public func trigger(entered: Bool) -> ModeTrigger? {
        guard kind == .custom else { return kind.trigger(entered: entered) }
        switch action {
        case .boxing: return HubPlace.Kind.gym.trigger(entered: entered)
        case .work: return entered ? .enteredOffice : .leftOffice
        case .chill: return entered ? .enteredPlace(.chill, name: title) : nil
        case .sideHustle: return entered ? .enteredPlace(.money, name: title) : nil
        case .recordOnly, .fitness: return nil
        }
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

    /// iOS watches at most 20 regions per app.
    public static let limit = 20

    /// The preset place of `kind`, if set. Setting `nil` removes it.
    public subscript(kind: HubPlace.Kind) -> HubPlace? {
        get { places.first { $0.kind == kind && $0.id == kind.rawValue } }
        set {
            places.removeAll { $0.kind == kind && $0.id == kind.rawValue }
            if let newValue { places.append(newValue) }
        }
    }

    /// The places Mike added, in the order he added them.
    public var custom: [HubPlace] { places.filter { $0.kind == .custom } }

    /// True while another place fits under `limit`.
    public var canAdd: Bool { places.count < Self.limit }

    /// Adds `place` or replaces the one with its id.
    /// - Returns: `false` when it is new and `limit` is reached.
    @discardableResult
    public mutating func save(_ place: HubPlace) -> Bool {
        if let index = places.firstIndex(where: { $0.id == place.id }) {
            places[index] = place
            return true
        }
        guard canAdd else { return false }
        places.append(place)
        return true
    }

    /// Removes the place with `id`.
    public mutating func remove(id: String) {
        places.removeAll { $0.id == id }
    }

    /// Every presence key some place sets.
    public var presenceKeys: Set<String> { Set(places.flatMap(\.presenceKeys)) }

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
    /// When Mike last left each place.
    public var departures: [String: Date]
    /// When the stay that ended at each departure began.
    public var lastArrivals: [String: Date]

    // GPS drift near a fence edge reports a quick leave and return. Shorter gaps count as one stay.
    /// A return this soon after leaving continues the stay; a leave this soon after arriving was a pass-by.
    public static let bounce: TimeInterval = 3 * 60

    public init(arrivals: [String: Date] = [:], departures: [String: Date] = [:], lastArrivals: [String: Date] = [:]) {
        self.arrivals = arrivals
        self.departures = departures
        self.lastArrivals = lastArrivals
    }

    private enum CodingKeys: String, CodingKey { case arrivals, departures, lastArrivals }

    /// Decodes the presence; builds before departures were kept saved only arrivals.
    /// - Throws: `DecodingError` when a field has the wrong type.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        arrivals = try values.decodeIfPresent([String: Date].self, forKey: .arrivals) ?? [:]
        departures = try values.decodeIfPresent([String: Date].self, forKey: .departures) ?? [:]
        lastArrivals = try values.decodeIfPresent([String: Date].self, forKey: .lastArrivals) ?? [:]
    }

    /// When Mike last left `kind`, or `nil` when unknown.
    public func left(_ kind: HubPlace.Kind) -> Date? {
        departures[kind.rawValue]
    }

    /// When Mike arrived at `kind`, or `nil` when he isn't there.
    public func since(_ kind: HubPlace.Kind) -> Date? {
        arrivals[kind.rawValue]
    }

    /// Records arriving at (`entered`) or leaving `kind` at `date`. Repeated arrivals keep the first.
    public mutating func record(_ kind: HubPlace.Kind, entered: Bool, at date: Date) {
        record(key: kind.rawValue, entered: entered, at: date)
    }

    /// Records arriving at or leaving every key of `place`.
    public mutating func record(_ place: HubPlace, entered: Bool, at date: Date) {
        for key in place.presenceKeys {
            record(key: key, entered: entered, at: date)
        }
    }

    /// When Mike arrived at `place`, or `nil` when he isn't there.
    public func since(_ place: HubPlace) -> Date? {
        place.presenceKeys.compactMap { arrivals[$0] }.min()
    }

    /// When Mike arrived at the place with presence key `key`, or `nil` when he isn't there.
    public func since(key: String) -> Date? {
        arrivals[key]
    }

    /// Records leaving every place not in `keys`, for places that were removed and can't report it.
    public mutating func leaveAll(except keys: Set<String>, at date: Date) {
        for key in arrivals.keys where !keys.contains(key) {
            record(key: key, entered: false, at: date)
        }
    }

    private mutating func record(key: String, entered: Bool, at date: Date) {
        if entered {
            guard arrivals[key] == nil else { return }
            let returned = departures[key].map { date.timeIntervalSince($0) < Self.bounce } ?? false
            arrivals[key] = returned ? (lastArrivals[key] ?? date) : date
        } else if let stay = arrivals[key] {
            departures[key] = date
            lastArrivals[key] = stay
            arrivals[key] = nil
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
