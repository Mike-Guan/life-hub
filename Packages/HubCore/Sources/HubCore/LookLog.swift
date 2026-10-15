import Foundation

// Issue #352. A keepsake or outfit keeps how its character looked when it arrived, for the keepsake page
// and the share card. Kept in its own file, not on `CanEntry`: an older build drops unknown fields on
// readable ledger entries when it saves, and would erase the look (DW-02).

/// How a character looked at one moment: her mode, what she wore and her identity card.
public struct Look: Equatable, Sendable {
    // Raw names, like `CanEntry.cardName`, so a mode or card from a newer build is written back unchanged.
    /// The raw `Mode` name, `nil` when the mode wasn't known.
    public var modeName: String?
    public var wardrobe: Wardrobe
    /// The raw `IdentityKind` name, `nil` when no card was picked.
    public var cardName: String?

    public init(mode: Mode?, wardrobe: Wardrobe, card: IdentityKind?) {
        self.modeName = mode?.rawValue
        self.wardrobe = wardrobe
        self.cardName = card?.rawValue
    }

    /// The mode, `nil` when unknown to this build or not recorded.
    public var mode: Mode? { modeName.flatMap(Mode.init(rawValue:)) }

    /// The identity card, `nil` when unknown to this build or none was picked.
    public var card: IdentityKind? { cardName.flatMap(IdentityKind.init(rawValue:)) }

    // Wins can be imported or back-filled days later, and the wardrobe keeps no history. Only a moment
    // from today is close enough to say this was the look then; older ones get no snapshot.
    /// The look at `date`: the mode `log` had then and `wardrobe`, or `nil` when `date` isn't today.
    /// - Parameters:
    ///   - wardrobe: what the character wears now.
    ///   - card: the identity card picked now.
    public static func at(
        _ date: Date,
        log: ModeLog,
        wardrobe: Wardrobe,
        card: IdentityKind?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Look? {
        guard date <= now, calendar.isDate(date, inSameDayAs: now) else { return nil }
        let mode = log.active.last { $0.at <= date }?.mode
        return Look(mode: mode, wardrobe: wardrobe, card: card)
    }
}

/// The look of one character when one ledger entry gave her an item.
public struct LookSnapshot: Codable, Identifiable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    /// The id of the `CanEntry` that gave the item, so each item keeps one snapshot.
    public var id: UUID
    public var persona: Persona
    public var itemID: String
    public var look: Look
    public var createdAt: Date
    public var updatedAt: Date
    public var updatedBy: String
    public var deletedAt: Date?

    public init(entry: UUID, persona: Persona, itemID: String, look: Look, at date: Date, deviceID: String) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = entry
        self.persona = persona
        self.itemID = itemID
        self.look = look
        self.createdAt = date
        self.updatedAt = date
        self.updatedBy = deviceID
        self.deletedAt = nil
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, persona, itemID, mode, wardrobe, card
        case createdAt, updatedAt, updatedBy, deletedAt
    }

    // An unknown persona throws, so the log keeps the raw record instead of giving it to someone else.
    /// Decodes a snapshot. `id`, `persona` and `itemID` are required.
    /// - Throws: `DecodingError` when a required field is missing or invalid.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        id = try values.decode(UUID.self, forKey: .id)
        persona = try values.decode(Persona.self, forKey: .persona)
        itemID = try values.decode(String.self, forKey: .itemID)
        let wardrobe = try values.decodeIfPresent(Wardrobe.self, forKey: .wardrobe) ?? Wardrobe()
        var look = Look(mode: nil, wardrobe: wardrobe, card: nil)
        look.modeName = try values.decodeIfPresent(String.self, forKey: .mode)
        look.cardName = try values.decodeIfPresent(String.self, forKey: .card)
        self.look = look
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt) ?? .distantPast
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        updatedBy = try values.decodeIfPresent(String.self, forKey: .updatedBy) ?? "unknown"
        deletedAt = try values.decodeIfPresent(Date.self, forKey: .deletedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(id, forKey: .id)
        try values.encode(persona, forKey: .persona)
        try values.encode(itemID, forKey: .itemID)
        try values.encodeIfPresent(look.modeName, forKey: .mode)
        try values.encode(look.wardrobe, forKey: .wardrobe)
        try values.encodeIfPresent(look.cardName, forKey: .card)
        try values.encode(createdAt, forKey: .createdAt)
        try values.encode(updatedAt, forKey: .updatedAt)
        try values.encode(updatedBy, forKey: .updatedBy)
        try values.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }
}

/// The look snapshots, one per item given. This is the on-disk document.
public struct LookLog: RecordLog, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var snapshots: [LookSnapshot]
    // Kept as-is and written back on save, so an older build never deletes newer data (DW-02).
    /// Records this build can't read.
    public var unreadable: [JSONValue]

    public var records: [LookSnapshot] {
        get { snapshots }
        set { snapshots = newValue }
    }

    public init() { self.init(snapshots: []) }

    public init(snapshots: [LookSnapshot]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.snapshots = snapshots
        self.unreadable = []
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, snapshots }

    /// Decodes the log, moving records that fail to decode into `unreadable`.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        let items = try values.decodeIfPresent([LossyRecord<LookSnapshot>].self, forKey: .snapshots) ?? []
        snapshots = items.compactMap(\.value)
        unreadable = items.filter { $0.value == nil }.map(\.raw)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        var list = values.nestedUnkeyedContainer(forKey: .snapshots)
        for snapshot in snapshots { try list.encode(snapshot) }
        for raw in unreadable { try list.encode(raw) }
    }

    /// The look kept for the ledger entry `entry`, `nil` when none was kept.
    public func look(for entry: UUID) -> Look? {
        snapshots.first { $0.id == entry && $0.deletedAt == nil }?.look
    }

    /// The look `persona` had when `itemID` reached her, `nil` when none was kept.
    public func look(of itemID: String, persona: Persona) -> Look? {
        snapshots.first { $0.itemID == itemID && $0.persona == persona && $0.deletedAt == nil }?.look
    }
}

extension LookLog {
    // GrowthStore is the log's single writer, so this only reads the file and never moves it aside.
    /// The log in the file at `url`, or an empty one when there is none or it can't be read.
    public static func read(from url: URL?) -> LookLog {
        guard let url, let data = try? Data(contentsOf: url) else { return LookLog() }
        return (try? HubJSON.decoder().decode(LookLog.self, from: data)) ?? LookLog()
    }
}
