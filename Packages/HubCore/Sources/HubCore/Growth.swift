import CryptoKit
import Foundation

/// A real-life win that earns cans. Detected automatically, never entered by hand.
public enum Win: String, Codable, CaseIterable, Sendable {
    /// A weekday gym visit or a strength workout.
    case gym
    /// Sunday boxing class.
    case boxing
    /// A run of 5 km or more.
    case run5k
    /// Got up within 30 minutes of an invite.
    case gotUp
    /// Time in daylight.
    case daylight
    /// Fell asleep soon after bedtime.
    case earlySleep

    /// Cans this win earns.
    public var cans: Int {
        switch self {
        case .boxing, .run5k: 5
        case .gym: 3
        case .gotUp: 2
        case .daylight, .earlySleep: 1
        }
    }
}

/// One line in the can ledger. Stored append-only; the balance and owned items are computed from these.
public struct CanEntry: Codable, Identifiable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    /// What the line records.
    public enum Kind: String, Codable, Sendable {
        /// Cans earned for `win`.
        case earned
        /// `itemID` bought for `cans`.
        case bought
        /// `itemID` given as a keepsake, for free.
        case granted
    }

    public var schemaVersion: Int
    public var id: UUID
    public var kind: Kind
    public var at: Date
    public var cans: Int
    public var win: Win?
    public var itemID: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var updatedBy: String
    public var deletedAt: Date?

    public init(id: UUID, kind: Kind, at: Date, cans: Int, win: Win? = nil, itemID: String? = nil, deviceID: String) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.kind = kind
        self.at = at
        self.cans = cans
        self.win = win
        self.itemID = itemID
        self.createdAt = at
        self.updatedAt = at
        self.updatedBy = deviceID
        self.deletedAt = nil
    }

    // The id comes from the win and its source (a workout id, a night, an invite), so importing
    // the same win again finds the existing entry.
    /// Cans earned for `win`, identified by `source`.
    public static func earned(_ win: Win, source: String, at: Date, deviceID: String) -> CanEntry {
        CanEntry(
            id: .derived(from: "win:\(win.rawValue):\(source)"),
            kind: .earned,
            at: at,
            cans: win.cans,
            win: win,
            deviceID: deviceID
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, kind, at, cans, win, itemID, createdAt, updatedAt, updatedBy, deletedAt
    }

    // An unknown kind or win throws, so the ledger keeps the raw record instead of guessing.
    /// Decodes an entry. `id`, `kind` and `at` are required.
    /// - Throws: `DecodingError` when a required field is missing or invalid.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        id = try values.decode(UUID.self, forKey: .id)
        kind = try values.decode(Kind.self, forKey: .kind)
        at = try values.decode(Date.self, forKey: .at)
        cans = try values.decodeIfPresent(Int.self, forKey: .cans) ?? 0
        win = try values.decodeIfPresent(Win.self, forKey: .win)
        itemID = try values.decodeIfPresent(String.self, forKey: .itemID)
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt) ?? at
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        updatedBy = try values.decodeIfPresent(String.self, forKey: .updatedBy) ?? "unknown"
        deletedAt = try values.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

/// The can ledger. This is the on-disk document.
public struct CanLedger: RecordLog, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var entries: [CanEntry]
    // Kept as-is and written back on save, so an older build never deletes newer data (DW-02).
    /// Records this build can't read.
    public var unreadable: [JSONValue]

    public var records: [CanEntry] {
        get { entries }
        set { entries = newValue }
    }

    public init() { self.init(entries: []) }

    public init(entries: [CanEntry]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.entries = entries
        self.unreadable = []
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, entries }

    /// Decodes the ledger, moving records that fail to decode into `unreadable`.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        let items = try values.decodeIfPresent([LossyRecord<CanEntry>].self, forKey: .entries) ?? []
        entries = items.compactMap(\.value)
        unreadable = items.filter { $0.value == nil }.map(\.raw)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        var list = values.nestedUnkeyedContainer(forKey: .entries)
        for entry in entries { try list.encode(entry) }
        for raw in unreadable { try list.encode(raw) }
    }

    /// Non-deleted entries, oldest first.
    public var active: [CanEntry] {
        entries.filter { $0.deletedAt == nil }.sorted { $0.at < $1.at }
    }

    /// Cans earned minus cans spent.
    public var balance: Int {
        active.reduce(0) { total, entry in
            switch entry.kind {
            case .earned: total + entry.cans
            case .bought: total - entry.cans
            case .granted: total
            }
        }
    }

    /// Ids of items bought or granted.
    public var owned: Set<String> {
        Set(active.filter { $0.kind != .earned }.compactMap(\.itemID))
    }

    /// How many times `win` was earned.
    public func count(_ win: Win) -> Int {
        active.filter { $0.kind == .earned && $0.win == win }.count
    }
}

/// Where an item is worn or shown.
public enum Slot: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case gloves
    case headband
    case shoes
    case mask
    case room
    case celebration
}

/// Something HAKU can own: bought in the shop, or granted as a keepsake.
public struct ShopItem: Identifiable, Equatable, Sendable {
    /// A milestone that grants an item for free.
    public struct Keepsake: Equatable, Sendable {
        public var win: Win
        public var count: Int
    }

    public var id: String
    public var slot: Slot
    public var title: String
    /// Price in cans; `nil` for a keepsake, which can't be bought.
    public var price: Int?
    public var keepsake: Keepsake?

    // The first catalog (PRD v4.2 section 13). Ids are stored in the ledger, so never reuse one.
    /// Everything HAKU can own.
    public static let catalog: [ShopItem] = [
        ShopItem(id: "headband.cyan", slot: .headband, title: "青色头带", price: 15),
        ShopItem(id: "mask.lightning", slot: .mask, title: "闪电面罩", price: 20),
        ShopItem(id: "gloves.pink", slot: .gloves, title: "霓虹粉拳套", price: 30),
        ShopItem(id: "room.plant", slot: .room, title: "房间绿植", price: 10),
        ShopItem(id: "room.bag", slot: .room, title: "房间小沙袋", price: 25),
        ShopItem(id: "gloves.gold", slot: .gloves, title: "金拳套", keepsake: Keepsake(win: .boxing, count: 10)),
        ShopItem(id: "shoes.volt", slot: .shoes, title: "闪电跑鞋", keepsake: Keepsake(win: .run5k, count: 4)),
        ShopItem(id: "celebrate.up", slot: .celebration, title: "起身庆祝", keepsake: Keepsake(win: .gotUp, count: 1)),
    ]

    init(id: String, slot: Slot, title: String, price: Int? = nil, keepsake: Keepsake? = nil) {
        self.id = id
        self.slot = slot
        self.title = title
        self.price = price
        self.keepsake = keepsake
    }

    /// The catalog item with `id`.
    public static func item(_ id: String) -> ShopItem? {
        catalog.first { $0.id == id }
    }
}

/// Which owned item HAKU wears in each slot. A setting, so it is replaced in place.
public struct Wardrobe: Codable, Equatable, Sendable {
    public var equipped: [Slot: String]

    public init(equipped: [Slot: String] = [:]) {
        self.equipped = equipped
    }

    /// Wears `item` in its slot, replacing what was there.
    public mutating func equip(_ item: ShopItem) {
        equipped[item.slot] = item.id
    }

    /// Takes off whatever is in `slot`.
    public mutating func clear(_ slot: Slot) {
        equipped[slot] = nil
    }

    static let defaultsKey = "wardrobe"

    /// The wardrobe saved in `defaults`, or an empty one when none is saved or it can't be read.
    public static func stored(in defaults: UserDefaults) -> Wardrobe {
        guard let data = defaults.data(forKey: defaultsKey) else { return Wardrobe() }
        return (try? JSONDecoder().decode(Wardrobe.self, from: data)) ?? Wardrobe()
    }

    /// Saves the wardrobe in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }
}

extension UUID {
    /// A UUID that depends only on `name`.
    static func derived(from name: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(name.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
            )
        )
    }
}
