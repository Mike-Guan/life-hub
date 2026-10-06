import Foundation

// Issue #152 and product principles section 11. Groundwork only: nothing builds, stores or sends a card
// yet. The card is the one thing meant to leave the device, so it lives in its own file and holds only
// what the person chose to show. Raw records (places, times, sleep, Screen Time) never go into it.

/// An activity HAKU can act out for someone the person shares with (tier ②). Never shown as text.
public enum SharedActivity: String, Codable, CaseIterable, Sendable {
    case gym
    case boxing
    case running
    case walking
    case coding
    case shooting
}

/// How much one relationship sees.
public enum ShareTier: String, Codable, CaseIterable, Sendable {
    /// ① Mode and face only. The default.
    case look
    /// ② Also what HAKU is doing, minus the activities switched off.
    case activity
}

/// What one relationship may see: the tier and the activities hidden within it.
public struct SharePolicy: Codable, Equatable, Sendable {
    public var tier: ShareTier
    public var hidden: Set<SharedActivity>

    public init(tier: ShareTier = .look, hidden: Set<SharedActivity> = []) {
        self.tier = tier
        self.hidden = hidden
    }

    private enum CodingKeys: String, CodingKey { case tier, hidden }

    /// Decodes the policy; missing fields fall back to tier ① with nothing hidden.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        tier = try values.decodeIfPresent(ShareTier.self, forKey: .tier) ?? .look
        hidden = try values.decodeIfPresent(Set<SharedActivity>.self, forKey: .hidden) ?? []
    }
}

/// The share policy of each relationship, keyed by relationship id.
public struct ShareSettings: Codable, Equatable, Sendable {
    public var policies: [String: SharePolicy]

    public init(policies: [String: SharePolicy] = [:]) {
        self.policies = policies
    }

    /// The policy for `relationship`, tier ① when none was set.
    public func policy(for relationship: String) -> SharePolicy {
        policies[relationship] ?? SharePolicy()
    }
}

/// HAKU as others may see it.
public struct PublicCard: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var id: String
    /// The character's id. Random, so it names no person or account.
    public var characterID: String
    public var wardrobe: Wardrobe
    /// Ids of keepsakes earned, without dates.
    public var keepsakes: [String]
    public var mode: Mode?
    /// The face, from last night's sleep as a band only.
    public var face: EnergyLevel?
    public var activity: SharedActivity?
    public var createdAt: Date
    public var updatedAt: Date
    public var updatedBy: String
    public var deletedAt: Date?

    public init(
        id: String = UUID().uuidString,
        characterID: String,
        wardrobe: Wardrobe = Wardrobe(),
        keepsakes: [String] = [],
        mode: Mode? = nil,
        face: EnergyLevel? = nil,
        activity: SharedActivity? = nil,
        at date: Date = .now,
        deviceID: String
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.characterID = characterID
        self.wardrobe = wardrobe
        self.keepsakes = keepsakes.sorted()
        self.mode = mode
        self.face = face
        self.activity = activity
        self.createdAt = date
        self.updatedAt = date
        self.updatedBy = deviceID
        self.deletedAt = nil
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, characterID, wardrobe, keepsakes, mode, face, activity
        case createdAt, updatedAt, updatedBy, deletedAt
    }

    /// Decodes the card; missing fields fall back to defaults.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        id = try values.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        characterID = try values.decodeIfPresent(String.self, forKey: .characterID) ?? ""
        wardrobe = try values.decodeIfPresent(Wardrobe.self, forKey: .wardrobe) ?? Wardrobe()
        keepsakes = try values.decodeIfPresent([String].self, forKey: .keepsakes) ?? []
        mode = try? values.decodeIfPresent(Mode.self, forKey: .mode)
        face = try? values.decodeIfPresent(EnergyLevel.self, forKey: .face)
        activity = try? values.decodeIfPresent(SharedActivity.self, forKey: .activity)
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt) ?? .distantPast
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        updatedBy = try values.decodeIfPresent(String.self, forKey: .updatedBy) ?? ""
        deletedAt = try values.decodeIfPresent(Date.self, forKey: .deletedAt)
    }

    /// The card as one relationship sees it under `policy`: tier ① drops the activity, and tier ②
    /// drops it when it is hidden.
    public func shared(with policy: SharePolicy) -> PublicCard {
        var copy = self
        if policy.tier == .look || activity.map { policy.hidden.contains($0) } == true { copy.activity = nil }
        return copy
    }

    /// The card in the file at `url`, or `nil` when there is none or it can't be read.
    public static func read(from url: URL?) -> PublicCard? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? HubJSON.decoder().decode(PublicCard.self, from: data)
    }

    /// Writes the card to `url`, replacing what was there.
    public func write(to url: URL) throws {
        try HubJSON.encoder().encode(self).write(to: url, options: .atomic)
    }
}

/// The character's id, stored in user defaults.
public enum HubCharacter {
    static let key = "characterID"

    /// The id kept in `defaults`, created on first use.
    public static func id(defaults: UserDefaults) -> String {
        if let existing = defaults.string(forKey: key) { return existing }
        let id = UUID().uuidString
        defaults.set(id, forKey: key)
        return id
    }
}
