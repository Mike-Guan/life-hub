#if os(iOS) || os(macOS)
import Foundation
import HubCore

@testable import CompanionKit

// Fabricated data for the home tests: a snapshot the way the app would send one.
extension HomeModel {
    /// The room's clock starts here: the first two wander slots of this day have no walk.
    static let start = Date(timeIntervalSinceReferenceDate: 0)

    convenience init(night: Bool, card: IdentityKind = .boxing, mode: Mode? = nil, energy: EnergyLevel? = nil) {
        var snapshot = HomeSnapshot.preview()
        snapshot.cards = ModeCards(identity: card)
        snapshot.mode = mode
        snapshot.energy = energy
        self.init(snapshot: snapshot, night: night, now: Self.start)
    }

    /// Hands the model a snapshot in which the character owns `item` and it stands in the room, as after a purchase
    /// in the shop.
    func own(_ item: HomeItem) {
        var next = snapshot
        let id = "room.\(item.rawValue)"
        next.owned.insert(id)
        next.room.place([id], catalog: .shipped, now: now, deviceID: "test")
        apply(next)
    }

    /// Hands the model a snapshot in which the character owns `items`, each standing in its zone, placed in order.
    /// The ids aren't in the shop catalog yet, so the zones are set here rather than by `RoomLayout.place`.
    func stand(_ items: [HomeItem]) {
        var next = snapshot
        for (i, item) in items.enumerated() {
            let id = "haku.room.\(item.rawValue)"
            next.owned.insert(id)
            var placement = RoomPlacement(piece: id)
            placement.zone = item.zone.rawValue
            placement.placedAt = now.addingTimeInterval(Double(i))
            next.room.placements.append(placement)
        }
        apply(next)
    }

    /// Hands the model a snapshot in which the character owns `outfit` and wears it, in its mode.
    func wear(_ outfit: HomeOutfit) {
        guard let id = outfit.shopID, let item = ShopItem.item(id) else { return }
        var next = snapshot
        next.owned.insert(id)
        next.wardrobe.equip(item)
        next.mode = item.mode ?? next.mode
        apply(next)
    }
}
#endif
