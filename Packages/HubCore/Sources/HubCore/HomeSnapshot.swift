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
        keepsakes: [EarnedKeepsake] = []
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
