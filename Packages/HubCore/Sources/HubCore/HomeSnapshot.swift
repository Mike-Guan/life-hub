import Foundation

// Issue #489. The app builds this each time the home page opens, from the same stores the home screen reads,
// so the room shows real data. It is never saved; changes go back through the page's callbacks.
/// What the home page shows: the mode, the cards, the cans, what the character owns and wears, her face and room.
public struct HomeSnapshot: Equatable, Sendable {
    public var persona: Persona
    /// The current mode, `nil` before the first one.
    public var mode: Mode?
    public var cards: ModeCards
    /// The picked character's can balance.
    public var cans: Int
    /// Ids of the items the character owns, bought or granted.
    public var owned: Set<String>
    public var wardrobe: Wardrobe
    /// Today's energy, for the face only; `nil` when unknown.
    public var energy: EnergyLevel?
    public var vitals: HakuVitals
    public var bedtime: Bedtime
    /// Today's modes, oldest first.
    public var today: [ModeSegment]
    public var room: RoomLayout
    /// The keepsakes the character earned, oldest first, for the reward shelf.
    public var keepsakes: [EarnedKeepsake]
    /// Whether the character boxed often enough for her gloves to look worn; they stand on the reward shelf.
    public var wornGloves: Bool

    public init(
        persona: Persona,
        mode: Mode?,
        cards: ModeCards,
        cans: Int,
        owned: Set<String>,
        wardrobe: Wardrobe,
        energy: EnergyLevel?,
        vitals: HakuVitals,
        bedtime: Bedtime,
        today: [ModeSegment],
        room: RoomLayout,
        keepsakes: [EarnedKeepsake] = [],
        wornGloves: Bool = false
    ) {
        self.persona = persona
        self.mode = mode
        self.cards = cards
        self.cans = cans
        self.owned = owned
        self.wardrobe = wardrobe
        self.energy = energy
        self.vitals = vitals
        self.bedtime = bedtime
        self.today = today
        self.room = room
        self.keepsakes = keepsakes
        self.wornGloves = wornGloves
    }

    // 家 真实数据清单 v0 (Mike 2026-10-17: the home page shows only real data). Every field comes from the store
    // the home screen reads. Room items owned but not yet in the room are placed, and the layout saved.
    /// The home page's snapshot for `persona` from the app's stores.
    /// - Parameters:
    ///   - mode: the current mode, `nil` before the first.
    ///   - today: today's modes, oldest first.
    ///   - ledger: the whole can ledger; the snapshot reads `persona`'s part.
    ///   - energy: the energy log, for today's level and the hidden params.
    ///   - bedtime: the bedtime state now.
    ///   - defaults: the App Group defaults holding the cards, wardrobe and room layout.
    public static func make(
        persona: Persona,
        mode: Mode?,
        today: [ModeSegment],
        ledger: CanLedger,
        energy: EnergyLog,
        bedtime: Bedtime,
        defaults: UserDefaults,
        catalog: RoomCatalog = .shipped,
        now: Date = Date()
    ) -> HomeSnapshot {
        let mine = ledger.only(persona)
        let deviceID = HubDevice.id(defaults: defaults)
        var room = RoomLayout.loaded(in: defaults, persona: persona, catalog: catalog, now: now, deviceID: deviceID)
        let roomItems = mine.owned.filter { ShopItem.item($0)?.slot == .room }.sorted()
        if !room.place(roomItems, catalog: catalog, now: now, deviceID: deviceID).isEmpty {
            room.store(in: defaults)
        }
        return HomeSnapshot(
            persona: persona,
            mode: mode,
            cards: ModeCards.current(in: defaults, persona: persona),
            cans: mine.balance,
            owned: mine.owned,
            wardrobe: Wardrobe.stored(in: defaults, persona: persona),
            energy: StateEngine.energy(events: energy.active, now: now)?.level,
            vitals: VitalsEngine.vitals(ledger: mine, energy: energy, now: now),
            bedtime: bedtime,
            today: today,
            room: room,
            keepsakes: EarnedKeepsake.earned(in: ledger, persona: persona),
            // Mike 2026-10-18: the worn gloves he earned were missing from the home's reward shelf.
            wornGloves: mine.count(.boxing, card: .boxing) >= MomentEngine.glovesAfter
        )
    }

    /// The items worn in the current mode, or in Chill before the first mode, without other cards' items.
    public var worn: Set<String> {
        wardrobe.showing(card: cards.identity).worn(in: mode ?? .chill)
    }

    /// The room items the character owns and has not placed, so the page can offer them.
    public var unplaced: [String] {
        let placed = Set(room.placements.map(\.piece))
        return owned.filter { ShopItem.item($0)?.slot == .room && !placed.contains($0) }.sorted()
    }
}

/// A keepsake on the reward shelf: which one and when it was earned.
public struct EarnedKeepsake: Equatable, Sendable {
    /// The keepsake's shop item id.
    public var id: String
    public var at: Date

    public init(id: String, at: Date) {
        self.id = id
        self.at = at
    }

    // 商店与家 同步方案 §5: only real keepsakes, with their real dates. Unearned ones leave no gap on the shelf.
    /// The keepsakes `persona` earned in `ledger`, oldest first.
    public static func earned(in ledger: CanLedger, persona: Persona) -> [EarnedKeepsake] {
        let mine = ledger.only(persona)
        return ShopItem.catalog(for: persona)
            .compactMap { item in
                guard item.keepsake != nil, let at = mine.ownedAt(item.id) else { return nil }
                return EarnedKeepsake(id: item.id, at: at)
            }
            .sorted { $0.at < $1.at }
    }
}
