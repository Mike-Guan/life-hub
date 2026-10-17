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
        room: RoomLayout
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
