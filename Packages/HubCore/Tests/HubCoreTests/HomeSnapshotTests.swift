import Foundation
import Testing

@testable import HubCore

@Suite struct HomeSnapshotTests {
    func snapshot(mode: Mode?, owned: Set<String>, wardrobe: Wardrobe, room: RoomLayout) -> HomeSnapshot {
        HomeSnapshot(
            persona: .haku,
            mode: mode,
            cards: ModeCards(identity: .boxing),
            cans: 12,
            owned: owned,
            wardrobe: wardrobe,
            energy: .full,
            vitals: HakuVitals(),
            bedtime: .off,
            today: [],
            room: room
        )
    }

    @Test func wornFollowsTheModeAndChillBeforeTheFirst() {
        let wardrobe = Wardrobe(equipped: [.headband: "headband.red", .hat: "hat.beanie"])
        let room = RoomLayout(persona: .haku, deviceID: "phone")
        let work = snapshot(mode: .work, owned: [], wardrobe: wardrobe, room: room)
        #expect(work.worn == ["headband.red"])
        let none = snapshot(mode: nil, owned: [], wardrobe: wardrobe, room: room)
        #expect(none.worn == ["headband.red", "hat.beanie"])
    }

    @Test func unplacedListsOwnedRoomItemsNotInTheRoom() {
        var room = RoomLayout(persona: .haku, deviceID: "phone")
        room.placements = [RoomPlacement(piece: "room.plant", at: RoomCell(x: 1, y: 1))]
        let home = snapshot(
            mode: .chill, owned: ["room.plant", "room.bag", "headband.red", "unknown.item"], wardrobe: Wardrobe(),
            room: room)
        #expect(home.unplaced == ["room.bag"])
        #expect(home.cans == 12)
        #expect(home.energy == .full)
    }

    @Test func theShelfHoldsEarnedKeepsakesOldestFirst() {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        func entry(_ item: String, _ kind: CanEntry.Kind, days: Double, persona: Persona = .haku) -> CanEntry {
            CanEntry(
                id: UUID(),
                kind: kind,
                at: day.addingTimeInterval(days * 86_400),
                cans: 0,
                itemID: item,
                persona: persona,
                deviceID: "t"
            )
        }
        let ledger = CanLedger(entries: [
            entry("gloves.gold", .granted, days: 9),
            entry("room.plant", .bought, days: 1),
            entry("celebrate.up", .granted, days: 2),
            entry("celebrate.up", .granted, days: 3, persona: .kuro),
        ])
        let shelf = EarnedKeepsake.earned(in: ledger, persona: .haku)
        #expect(shelf.map(\.id) == ["celebrate.up", "gloves.gold"])
        #expect(shelf.first?.at == day.addingTimeInterval(2 * 86_400))
        #expect(EarnedKeepsake.earned(in: CanLedger(), persona: .haku).isEmpty)
    }
}
