import CryptoKit
import Foundation

/// A real-life win that earns cans. Detected automatically, never entered by hand.
public enum Win: String, Codable, CaseIterable, Sendable {
    // Issue #279: raw names are stored in the ledger, so `gym` and `boxing` keep their first names.
    /// A visit to the fitness gym or a strength workout.
    case gym
    /// A session of the identity card: its watch workout or a visit to its place, 30 minutes or more.
    case boxing
    /// A run of 5 km or more.
    case run5k
    /// Got up within 30 minutes of an invite.
    case gotUp
    /// Time in daylight.
    case daylight
    /// Fell asleep soon after bedtime.
    case earlySleep
    /// Finished a task planned ahead in Daily Widget.
    case plannedTask
    /// Any other watch workout of 30 minutes or more.
    case exercise

    /// Cans this win earns.
    public var cans: Int {
        switch self {
        case .boxing, .run5k: 5
        case .gym, .exercise: 3
        case .gotUp: 2
        case .daylight, .earlySleep, .plannedTask: 1
        }
    }
}

/// A win found in what the app reads, with the id of what it came from.
public struct EarnedWin: Equatable, Sendable {
    public var win: Win
    /// What the win came from; the ledger counts each source once.
    public var source: String
    public var at: Date
    /// The identity card a `boxing` win was earned with, `nil` for other wins.
    public var card: IdentityKind?

    public init(win: Win, source: String, at: Date, card: IdentityKind? = nil) {
        self.win = win
        self.source = source
        self.at = at
        self.card = card
    }
}

extension Win {
    /// How often a win can earn cans.
    public enum Cap: Sendable {
        case day
        case week
    }

    // Caps from 03 Product/奖励数值表.md (PM, 2026-10-04). Planned tasks earn per task, up to
    // `DailyAgenda.dailyCanLimit` a day.
    /// The identity card earns once a week, every other win once a day.
    public var cap: Cap {
        self == .boxing ? .week : .day
    }

    // 03 Product/朋友测前 产品打磨清单 v0.md §2.5: a gym visit and any other workout earn one 3-can win a
    // day together. They stay two wins, so gym days are still learned from the gym alone.
    /// The win whose cap this win shares: `gym` for `exercise`, itself for every other win.
    public var capGroup: Win {
        self == .exercise ? .gym : self
    }

    /// The ledger source for this win at `date`: one per day or week, so the win earns at most once in it.
    public func source(at date: Date, calendar: Calendar = .current) -> String {
        switch cap {
        case .day:
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            return "\(capGroup.rawValue):\(day)"
        case .week:
            let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            let week = String(format: "%04d-W%02d", parts.yearForWeekOfYear ?? 0, parts.weekOfYear ?? 0)
            return "\(capGroup.rawValue):\(week)"
        }
    }

    /// How long a visit or a workout must last to earn a win.
    public static let visitMinimum: TimeInterval = 30 * 60

    /// Watch workouts that never earn the exercise win: walks and workouts the app can't group.
    static let notExercise: Set<WorkoutSummary.Kind> = [.walking, .other]

    // Issue #279. A workout of the identity card earns only the card's weekly win, so a card session is not
    // also counted as exercise. Strength stays the gym win at the celebration bar, so HAKU cheers what earns.
    /// The wins in `workouts`, each with the source for its cap: the identity card's win for its workouts of
    /// 30+ minutes, 5 km runs, the gym win for strength workouts and the exercise win for any other workout
    /// of 30+ minutes except walks.
    /// - Parameter identity: the picked identity card, `nil` when there is none.
    public static func wins(
        in workouts: [WorkoutSummary],
        identity: IdentityKind?,
        rules: NeedRules = .standard,
        calendar: Calendar = .current
    ) -> [EarnedWin] {
        workouts.flatMap { workout -> [EarnedWin] in
            func earned(_ win: Win, card: IdentityKind? = nil) -> EarnedWin {
                let source = win.source(at: workout.start, calendar: calendar)
                return EarnedWin(win: win, source: source, at: workout.end, card: card)
            }
            var wins: [EarnedWin] = []
            if workout.kind == .running, (workout.meters ?? 0) >= rules.celebrateRunMeters {
                wins.append(earned(.run5k))
            }
            if let identity, identity.workouts.contains(workout.kind) {
                if workout.duration >= visitMinimum { wins.append(earned(.boxing, card: identity)) }
            } else if workout.kind == .strength {
                if workout.duration >= rules.celebrateStrength { wins.append(earned(.gym)) }
            } else if !notExercise.contains(workout.kind), workout.duration >= visitMinimum {
                wins.append(earned(.exercise))
            }
            return wins
        }
    }

    // Mike boxes without a watch, so the card's place counts like the fitness gym. A visit and a workout
    // in the same day or week share one source, so they earn once together. With the fitness card the
    // fitness gym is the card's place, so a gym visit and a strength workout pay one card win, not two.
    /// The win for a visit to a place with `action` from `arrived` to `left`: the gym win for the fitness
    /// gym, the identity card's win for the card's place and, with the fitness card, for the fitness gym;
    /// `nil` for other places, without a card, or when the visit was too short.
    /// - Parameter identity: the picked identity card, `nil` when there is none.
    public static func visit(
        _ action: HubPlace.Action,
        from arrived: Date,
        to left: Date,
        identity: IdentityKind?,
        calendar: Calendar = .current
    ) -> EarnedWin? {
        let win: Win
        var card: IdentityKind?
        switch action {
        case .fitness where identity == .fitness:
            win = .boxing
            card = identity
        case .fitness: win = .gym
        case .boxing:
            guard let identity else { return nil }
            win = .boxing
            card = identity
        default: return nil
        }
        guard left.timeIntervalSince(arrived) >= visitMinimum else { return nil }
        return EarnedWin(win: win, source: win.source(at: arrived, calendar: calendar), at: left, card: card)
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
    /// The character whose cans or item this is.
    public var persona: Persona
    // Kept as the raw name, like `ModeCards.identityName`, so an older build writes an unknown card back.
    /// The raw `IdentityKind` name of the card a `boxing` win was earned with; `nil` on other entries and
    /// on entries from before identity cards.
    public var cardName: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var updatedBy: String
    public var deletedAt: Date?

    public init(
        id: UUID,
        kind: Kind,
        at: Date,
        cans: Int,
        win: Win? = nil,
        itemID: String? = nil,
        persona: Persona = .haku,
        card: IdentityKind? = nil,
        deviceID: String
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.kind = kind
        self.at = at
        self.cans = cans
        self.win = win
        self.itemID = itemID
        self.persona = persona
        self.cardName = card?.rawValue
        self.createdAt = at
        self.updatedAt = at
        self.updatedBy = deviceID
        self.deletedAt = nil
    }

    // The id comes from the win and its source (a workout id, a night, an invite), not the character,
    // so importing the same win again finds the existing entry and one win never pays both characters.
    // Wins sharing a cap share the id too, so the gym and exercise wins earn once a day together.
    /// Cans earned for `win` by `persona`, identified by `source`.
    /// - Parameter card: the identity card a `boxing` win was earned with.
    public static func earned(
        _ win: Win,
        source: String,
        at: Date,
        persona: Persona = .haku,
        card: IdentityKind? = nil,
        deviceID: String
    ) -> CanEntry {
        CanEntry(
            id: .derived(from: "win:\(win.capGroup.rawValue):\(source)"),
            kind: .earned,
            at: at,
            cans: win.cans,
            win: win,
            persona: persona,
            card: win == .boxing ? card : nil,
            deviceID: deviceID
        )
    }

    // Issue #279. Entries from before identity cards count for the card their character had then.
    /// The identity card this entry was earned with: its own, else its character's card from before
    /// identity cards; `nil` when the card is unknown to this build.
    public var card: IdentityKind? {
        guard let cardName else { return ModeCards.legacy(for: persona).identity }
        return IdentityKind(rawValue: cardName)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, kind, at, cans, win, itemID, persona, createdAt, updatedAt, updatedBy, deletedAt
        case cardName = "card"
    }

    // An unknown kind or win throws, so the ledger keeps the raw record instead of guessing.
    // Entries from before characters had their own cans have no persona. Those were HAKU's, except KURO's
    // keepsakes, which builds a10bf72 and a1c25ea granted alongside HAKU's; they stay hers.
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
        persona =
            try values.decodeIfPresent(Persona.self, forKey: .persona)
            ?? itemID.flatMap(ShopItem.item)?.persona ?? .haku
        cardName = try values.decodeIfPresent(String.self, forKey: .cardName)
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

    // Cans, items and keepsake progress belong to one character; the wins themselves are Mike's life,
    // so code that reads his life (gym days, tennis day, weekly changes) uses the whole ledger.
    /// The entries of `persona` only, for her balance, items and progress.
    public func only(_ persona: Persona) -> CanLedger {
        CanLedger(entries: entries.filter { $0.persona == persona })
    }

    /// Non-deleted entries, oldest first.
    public var active: [CanEntry] {
        entries.filter { $0.deletedAt == nil }.sorted { $0.at < $1.at }
    }

    /// Items of `persona` bought or granted whose entry isn't in `seen`, oldest first, for the unboxing.
    public func unboxings(seen: Set<UUID>, persona: Persona = .haku) -> [CanEntry] {
        active.filter { entry in
            guard entry.kind != .earned, !seen.contains(entry.id), let id = entry.itemID else { return false }
            return ShopItem.item(id)?.persona == persona
        }
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

    /// When the item with `id` was bought or granted, `nil` if it isn't owned.
    public func ownedAt(_ id: String) -> Date? {
        active.first { $0.kind != .earned && $0.itemID == id }?.at
    }

    /// How many times `win` was earned.
    public func count(_ win: Win) -> Int {
        active.filter { $0.kind == .earned && $0.win == win }.count
    }

    /// How many times `win` was earned, only with identity card `card` when it isn't `nil`.
    public func count(_ win: Win, card: IdentityKind?) -> Int {
        guard let card else { return count(win) }
        return active.filter { $0.kind == .earned && $0.win == win && $0.card == card }.count
    }
}

/// Where an item is worn or shown.
public enum Slot: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case gloves
    case headband
    case mask
    case room
    case celebration
    /// Clothes for one mode.
    case top
    /// A full outfit for one mode. It replaces that mode's top.
    case fullSet = "set"
}

// 商店完整目录 v0 §8 and §9.1: the wardrobe groups items by where they are worn, not by slot.
/// A group of items in the wardrobe.
public enum WardrobeShelf: String, CaseIterable, Sendable {
    /// Tops and full sets, worn per mode.
    case clothes
    /// Worn in every mode: headbands, masks, celebrations.
    case accessories
    /// The picked identity card's own items.
    case props
    case room

    /// The shelves the wardrobe shows while previewing `mode`: props only in the identity card's mode, with a card picked.
    public static func shelves(in mode: Mode, card: IdentityKind?) -> [WardrobeShelf] {
        allCases.filter { $0 != .props || (card != nil && mode == .boxing) }
    }
}

extension Slot {
    /// The wardrobe shelf the slot's items sit on.
    public var shelf: WardrobeShelf {
        switch self {
        case .top, .fullSet: .clothes
        case .headband, .mask, .celebration: .accessories
        case .gloves: .props
        case .room: .room
        }
    }
}

/// Something a character can own: bought in the shop, or granted as a keepsake.
public struct ShopItem: Identifiable, Equatable, Sendable {
    /// A milestone that grants an item for free.
    public struct Keepsake: Equatable, Sendable {
        public var win: Win
        public var count: Int
        /// The identity card whose wins count, `nil` when any count.
        public var card: IdentityKind?

        init(win: Win, count: Int, card: IdentityKind? = nil) {
            self.win = win
            self.count = count
            self.card = card
        }
    }

    public var id: String
    public var slot: Slot
    public var title: String
    /// Price in cans; `nil` for a keepsake, which can't be bought.
    public var price: Int?
    public var keepsake: Keepsake?
    /// The character who wears or shows it.
    public var persona: Persona
    /// The identity card it belongs to, `nil` when it suits every card. A keepsake belongs to its win's card.
    public var card: IdentityKind?
    /// The mode a top or full set is worn in, `nil` for items shown in every mode.
    public var mode: Mode?
    /// Whether the character art draws it. The shop leaves it off the shelf until then.
    public var isDrawn: Bool

    // The first catalog (PRD v4.2 section 13), then KURO's (奖励数值表 section 7, approved 2026-10-07).
    // Ids are stored in the ledger, so never reuse one. KURO's items reuse HAKU's slots: her hair ties are
    // headbands, her blanket is the mask slot, her tennis bag and racket are the gloves slot.
    /// Everything either character can own.
    public static let catalog: [ShopItem] = [
        ShopItem(id: "headband.cyan", slot: .headband, title: "青色头带", price: 10),
        ShopItem(id: "mask.stripes", slot: .mask, title: "条纹面罩", price: 12),
        ShopItem(id: "gloves.pink", slot: .gloves, title: "霓虹粉拳套", price: 20, card: .boxing),
        ShopItem(id: "room.plant", slot: .room, title: "房间绿植", price: 8),
        ShopItem(id: "room.bag", slot: .room, title: "房间小沙袋", price: 15, card: .boxing),
        ShopItem(
            id: "gloves.gold",
            slot: .gloves,
            title: "金拳套",
            keepsake: Keepsake(win: .boxing, count: 10, card: .boxing)
        ),
        ShopItem(
            id: "keepsake.headband.runner",
            slot: .headband,
            title: "跑者头带",
            keepsake: Keepsake(win: .run5k, count: 4)
        ),
        ShopItem(id: "celebrate.up", slot: .celebration, title: "起身庆祝", keepsake: Keepsake(win: .gotUp, count: 1)),
        ShopItem(id: "kuro.room.flower", slot: .room, title: "地上小粉花", price: 8, persona: .kuro),
        ShopItem(id: "kuro.hair.scrunchie", slot: .headband, title: "粉色发圈", price: 10, persona: .kuro),
        ShopItem(id: "kuro.blanket.cats", slot: .mask, title: "粉色猫猫毯", price: 12, persona: .kuro),
        ShopItem(id: "kuro.room.lamp", slot: .room, title: "猫耳台灯", price: 15, persona: .kuro),
        ShopItem(
            id: "kuro.bag.tennis",
            slot: .gloves,
            title: "粉色网球包",
            price: 20,
            persona: .kuro,
            card: .tennis
        ),
        ShopItem(
            id: "kuro.celebrate.spin",
            slot: .celebration,
            title: "藏不住转一圈",
            keepsake: Keepsake(win: .gotUp, count: 1),
            persona: .kuro
        ),
        ShopItem(
            id: "kuro.headband.sakura",
            slot: .headband,
            title: "樱色运动发带",
            keepsake: Keepsake(win: .run5k, count: 4),
            persona: .kuro
        ),
        ShopItem(
            id: "kuro.racket.gold",
            slot: .gloves,
            title: "金色网球拍",
            keepsake: Keepsake(win: .boxing, count: 10, card: .tennis),
            persona: .kuro
        ),  // Clothes (商店完整目录 v0 §1.1 and §2.1, prices of 2026-10-14), off the shelf until drawn.
        // HAKU's eight are the pop set Mike approved 2026-10-14; the second character's are still placeholders.
        ShopItem(clothes: "haku.top.work.blazer", slot: .top, title: "学院西装", price: 30, mode: .work),
        ShopItem(clothes: "haku.top.work.cardigan", slot: .top, title: "像素开衫", price: 35, mode: .work),
        ShopItem(clothes: "haku.top.chill.aloha", slot: .top, title: "浪花夏威夷衫", price: 30, mode: .chill),
        ShopItem(clothes: "haku.top.chill.flame", slot: .top, title: "火焰连帽卫衣", price: 40, mode: .chill),
        ShopItem(clothes: "haku.top.side.sukajan", slot: .top, title: "刺绣夹克", price: 35, mode: .money),
        ShopItem(clothes: "haku.top.side.arcade", slot: .top, title: "街机 T", price: 40, mode: .money),
        ShopItem(clothes: "haku.set.chill.varsity", slot: .fullSet, title: "校队夹克", price: 80, mode: .chill),
        ShopItem(clothes: "haku.set.work.raincoat", slot: .fullSet, title: "原宿雨衣", price: 90, mode: .work),
        ShopItem(clothes: "kuro.top.work.blouse", slot: .top, title: "蝴蝶结衬衫", price: 30, mode: .work, persona: .kuro),
        ShopItem(clothes: "kuro.top.work.vest", slot: .top, title: "针织马甲", price: 35, mode: .work, persona: .kuro),
        ShopItem(
            clothes: "kuro.top.chill.cardigan", slot: .top, title: "毛绒开衫", price: 30, mode: .chill, persona: .kuro),
        ShopItem(clothes: "kuro.top.chill.hoodie", slot: .top, title: "猫耳卫衣", price: 40, mode: .chill, persona: .kuro),
        ShopItem(clothes: "kuro.top.side.smock", slot: .top, title: "格子罩衫", price: 35, mode: .money, persona: .kuro),
        ShopItem(clothes: "kuro.top.side.denim", slot: .top, title: "牛仔外套", price: 40, mode: .money, persona: .kuro),
        ShopItem(
            clothes: "kuro.set.chill.picnic", slot: .fullSet, title: "野餐", price: 80, mode: .chill, persona: .kuro),
        ShopItem(clothes: "kuro.set.work.rain", slot: .fullSet, title: "雨天", price: 90, mode: .work, persona: .kuro),
    ]

    init(
        id: String,
        slot: Slot,
        title: String,
        price: Int? = nil,
        keepsake: Keepsake? = nil,
        persona: Persona = .haku,
        card: IdentityKind? = nil
    ) {
        self.id = id
        self.slot = slot
        self.title = title
        self.price = price
        self.keepsake = keepsake
        self.persona = persona
        self.card = card ?? keepsake?.card
        self.isDrawn = true
    }

    init(clothes id: String, slot: Slot, title: String, price: Int, mode: Mode, persona: Persona = .haku) {
        self.init(id: id, slot: slot, title: title, price: price, persona: persona)
        self.mode = mode
        isDrawn = false
    }

    /// Whether the shop offers it to someone who picked `card`.
    public func suits(_ card: IdentityKind?) -> Bool {
        self.card == nil || self.card == card
    }

    // The identity card lives in the boxing mode slot (ModeCards), so its props show only there.
    /// Whether the wardrobe lists it while previewing `mode` with `card` picked.
    public func shows(in mode: Mode, card: IdentityKind?) -> Bool {
        guard suits(card), WardrobeShelf.shelves(in: mode, card: card).contains(slot.shelf) else { return false }
        return self.mode == nil || self.mode == mode
    }

    /// The catalog item with `id`.
    public static func item(_ id: String) -> ShopItem? {
        catalog.first { $0.id == id }
    }

    /// The items `persona` can own, in catalog order.
    public static func catalog(for persona: Persona) -> [ShopItem] {
        catalog.filter { $0.persona == persona }
    }

    /// The items `persona` can buy or earn that suit `card` and are drawn, in catalog order.
    public static func catalog(for persona: Persona, card: IdentityKind?) -> [ShopItem] {
        catalog(for: persona).filter { $0.isDrawn && $0.suits(card) }
    }
}

/// Which owned item a character wears in each slot. A setting, so it is replaced in place.
public struct Wardrobe: Codable, Equatable, Sendable {
    public var equipped: [Slot: String]
    /// The top or full set worn in each mode.
    public var clothes: [Mode: String]

    public init(equipped: [Slot: String] = [:], clothes: [Mode: String] = [:]) {
        self.equipped = equipped
        self.clothes = clothes
    }

    // Clothes are keyed by the mode's raw value, so the JSON stays an object. Wardrobes saved before clothes load
    // with none, and older builds skip the field.
    enum CodingKeys: String, CodingKey {
        case equipped
        case clothes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        equipped = try container.decode([Slot: String].self, forKey: .equipped)
        let byName = try container.decodeIfPresent([String: String].self, forKey: .clothes) ?? [:]
        clothes = Dictionary(
            uniqueKeysWithValues: byName.compactMap { key, id in Mode(rawValue: key).map { ($0, id) } })
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(equipped, forKey: .equipped)
        try container.encode(
            Dictionary(uniqueKeysWithValues: clothes.map { ($0.key.rawValue, $0.value) }), forKey: .clothes)
    }

    /// Wears `item`: clothes in their mode, replacing that mode's top or set, anything else in its slot.
    public mutating func equip(_ item: ShopItem) {
        if let mode = item.mode {
            clothes[mode] = item.id
        } else {
            equipped[item.slot] = item.id
        }
    }

    /// Takes off whatever is in `slot`.
    public mutating func clear(_ slot: Slot) {
        equipped[slot] = nil
    }

    /// Takes off the top or set worn in `mode`.
    public mutating func undress(_ mode: Mode) {
        clothes[mode] = nil
    }

    /// Whether `item` is worn: clothes in their mode, anything else in its slot.
    public func isWearing(_ item: ShopItem) -> Bool {
        if let mode = item.mode { return clothes[mode] == item.id }
        return equipped[item.slot] == item.id
    }

    // A switched-away card's items stay stored, so switching back puts them on again. Ids this build
    // doesn't know stay, as in the rest of the wardrobe.
    /// What is drawn with `card` picked: the wardrobe without items that belong to another card.
    public func showing(card: IdentityKind?) -> Wardrobe {
        func shows(_ id: String) -> Bool { ShopItem.item(id)?.suits(card) ?? true }
        return Wardrobe(equipped: equipped.filter { shows($0.value) }, clothes: clothes.filter { shows($0.value) })
    }

    // HAKU keeps the original key, so wardrobes saved before KURO had one still load.
    static func defaultsKey(for persona: Persona) -> String {
        persona == .haku ? "wardrobe" : "wardrobe.\(persona.rawValue)"
    }

    /// `persona`'s wardrobe saved in `defaults`, or an empty one when none is saved or it can't be read.
    public static func stored(in defaults: UserDefaults, persona: Persona = .haku) -> Wardrobe {
        guard let data = defaults.data(forKey: defaultsKey(for: persona)) else { return Wardrobe() }
        return (try? JSONDecoder().decode(Wardrobe.self, from: data)) ?? Wardrobe()
    }

    /// Saves the wardrobe in `defaults` as `persona`'s.
    public func store(in defaults: UserDefaults, persona: Persona = .haku) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey(for: persona))
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

extension CanLedger {
    // GrowthStore is the ledger's single writer, so this only reads the file and never moves it aside.
    /// The ledger in the file at `url`, or an empty one when there is none or it can't be read.
    public static func read(from url: URL?) -> CanLedger {
        guard let url, let data = try? Data(contentsOf: url) else { return CanLedger() }
        return (try? HubJSON.decoder().decode(CanLedger.self, from: data)) ?? CanLedger()
    }
}
