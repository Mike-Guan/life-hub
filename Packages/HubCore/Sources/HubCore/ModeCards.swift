import Foundation

// Issue #273. The four `Mode` cases stay as slots, so stored mode changes need no migration: work,
// chill and money are the three common cards, boxing is the slot of the identity card the user picked.
/// A kind of identity card a user can pick for the fourth card.
public enum IdentityKind: String, Codable, CaseIterable, Sendable {
    case boxing
    case tennis
    case fitness
    case swimming
    case yoga
    case dance
    case ball
    case music
    case art
    case study
    case outdoor
    case ski

    // Kinds whose art is done for every character. A kind joins once UI finishes its art,
    // so a card that slips to a later release needs no other change.
    /// The kinds the picker shows.
    public static let released: [IdentityKind] = [.boxing, .tennis]

    /// Whether the picker shows this kind.
    public var isReleased: Bool { Self.released.contains(self) }

    /// The card's name.
    public var title: String {
        switch self {
        case .boxing: "拳击日"
        case .tennis: "网球日"
        case .fitness: "健身"
        case .swimming: "游泳"
        case .yoga: "瑜伽"
        case .dance: "跳舞"
        case .ball: "球类"
        case .music: "乐器"
        case .art: "画画手作"
        case .study: "自习"
        case .outdoor: "户外"
        case .ski: "滑雪"
        }
    }

    // Skiing has no group of its own yet: Health's snow sports fall under `.outdoor` with hiking,
    // so a hike would switch to the ski card. It gets its workout kind with the switching rules.
    /// The watch workouts that switch to this card. Empty when only a place or a tap does.
    public var workouts: Set<WorkoutSummary.Kind> {
        switch self {
        case .boxing: [.boxing]
        case .tennis: [.racket]
        case .fitness: [.strength]
        case .swimming: [.swimming]
        case .yoga: [.yoga]
        case .dance: [.dance]
        case .ball: [.ball]
        case .outdoor: [.outdoor]
        case .music, .art, .study, .ski: []
        }
    }
}

/// Something in Chill the user picked for the character to act out. Only things the app can sense.
public enum ChillActivity: String, Codable, CaseIterable, Sendable {
    case fitness
    case running
    case walking
    case yoga
    case cycling
    case swimming
    case ball
    case shopping

    /// The name in the picker.
    public var title: String {
        switch self {
        case .fitness: "健身"
        case .running: "跑步"
        case .walking: "散步晒太阳"
        case .yoga: "瑜伽拉伸"
        case .cycling: "骑车"
        case .swimming: "游泳"
        case .ball: "球类"
        case .shopping: "买菜逛街"
        }
    }
}

/// The user's four cards: names for the common ones, the picked identity card, Chill activities and
/// the 副业 states. Places say which card they switch to themselves (`HubPlace.action`).
public struct ModeCards: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    static let defaultsKey = "modeCards"

    // UI, 2026-10-13: the watch shows the name in the clock row at full size.
    /// The widest card name that fits the watch's clock row: 4 Chinese characters or 8 Latin letters.
    public static let nameWidth = 8
    /// How many 副业 states the user can pick.
    public static let sideStateLimit = 3

    public var schemaVersion: Int
    // Keyed by `Mode` raw value, so a slot this build doesn't know is kept, not fatal.
    /// The user's own names for the common cards. A missing name shows the default.
    public var names: [String: String]
    // Kept as the raw name, so an older build that doesn't know the kind writes it back unchanged.
    /// The identity card's raw `IdentityKind` name, `nil` when the user picked none.
    public var identityName: String?
    /// The Chill activities the character acts out.
    public var chill: Set<ChillActivity>
    /// The 副业 states tapping the character cycles through, in order. Never empty.
    public var sideStates: [SideHustle]

    public init(
        names: [String: String] = [:],
        identity: IdentityKind? = nil,
        chill: Set<ChillActivity> = Set(ChillActivity.allCases),
        sideStates: [SideHustle] = [.vibeCoding]
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.names = names
        self.identityName = identity?.rawValue
        self.chill = chill
        self.sideStates = sideStates.isEmpty ? [.vibeCoding] : sideStates
    }

    // Users from before #273 keep what their character had: HAKU's boxing, the second character's
    // tennis, every Chill activity and the three 副业 states.
    /// The cards an existing install had with `persona`.
    public static func legacy(for persona: Persona) -> ModeCards {
        ModeCards(
            identity: persona == .kuro ? .tennis : .boxing,
            sideStates: [.vibeCoding, .shooting, .operating]
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, names
        case identityName = "identity"
        case chill, sideStates
    }

    /// Decodes the cards; missing fields and values this build doesn't know fall back to the defaults.
    /// - Throws: `DecodingError` when the data is not an object.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = (try? values.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? 1
        names = (try? values.decodeIfPresent([String: String].self, forKey: .names)) ?? [:]
        identityName = try? values.decodeIfPresent(String.self, forKey: .identityName)
        let chillNames = try? values.decodeIfPresent([String].self, forKey: .chill)
        chill = chillNames.map { Set($0.compactMap(ChillActivity.init(rawValue:))) } ?? Set(ChillActivity.allCases)
        let sideNames = (try? values.decodeIfPresent([String].self, forKey: .sideStates)) ?? []
        let states = sideNames.compactMap(SideHustle.init(rawValue:))
        sideStates = states.isEmpty ? [.vibeCoding] : states
    }

    /// The identity card, `nil` when the user picked none or this build doesn't know it.
    public var identity: IdentityKind? {
        get { identityName.flatMap(IdentityKind.init(rawValue:)) }
        set { identityName = newValue?.rawValue }
    }

    /// The name of the card in `mode`'s slot: the user's name, else the identity card's, else the
    /// character's default.
    public func title(for mode: Mode, persona: Persona) -> String {
        if let name = names[mode.rawValue] { return name }
        if mode == .boxing, let identity { return identity.title }
        return mode.title(for: persona)
    }

    /// Renames the common card in `mode`'s slot, cut to `nameWidth`; an empty name restores the default.
    /// - Returns: `false`, changing nothing, for the identity slot.
    @discardableResult
    public mutating func rename(_ mode: Mode, to name: String) -> Bool {
        guard mode != .boxing else { return false }
        let trimmed = Self.fitted(name.trimmingCharacters(in: .whitespacesAndNewlines))
        names[mode.rawValue] = trimmed.isEmpty ? nil : trimmed
        return true
    }

    /// How wide `text` is on the watch: ASCII counts 1, anything else 2.
    public static func width(of text: String) -> Int {
        text.reduce(0) { $0 + ($1.isASCII ? 1 : 2) }
    }

    /// `text` cut to at most `nameWidth`.
    public static func fitted(_ text: String) -> String {
        var result = ""
        for character in text {
            guard width(of: result + String(character)) <= nameWidth else { break }
            result.append(character)
        }
        return result
    }

    /// Sets the 副业 states, keeping the first `sideStateLimit` distinct ones.
    /// - Returns: `false`, changing nothing, when `states` is empty.
    @discardableResult
    public mutating func pickSideStates(_ states: [SideHustle]) -> Bool {
        var picked: [SideHustle] = []
        for state in states where !picked.contains(state) && picked.count < Self.sideStateLimit {
            picked.append(state)
        }
        guard !picked.isEmpty else { return false }
        sideStates = picked
        return true
    }

    /// The 副业 state after `state` when the user taps the character. A state not picked goes to the first.
    public func next(after state: SideHustle) -> SideHustle {
        guard let index = sideStates.firstIndex(of: state) else { return sideStates[0] }
        return sideStates[(index + 1) % sideStates.count]
    }

    /// The identity card a workout of `kind` switches to, `nil` when the picked card has no such workout.
    public func card(for kind: WorkoutSummary.Kind) -> IdentityKind? {
        guard let identity, identity.workouts.contains(kind) else { return nil }
        return identity
    }

    /// The cards saved in `defaults`, or `nil` when none are saved or they can't be read.
    public static func stored(in defaults: UserDefaults) -> ModeCards? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(ModeCards.self, from: data)
    }

    /// Saves the cards in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }
}
