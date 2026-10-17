#if os(iOS) || os(macOS)
import Foundation
import HubCore

@testable import CompanionKit

// Fabricated data for the home tests: a snapshot the way the app would send one.
extension HomeModel {
    convenience init(night: Bool, card: IdentityKind = .boxing, mode: Mode? = nil, energy: EnergyLevel? = nil) {
        var snapshot = HomeSnapshot.preview()
        snapshot.cards = ModeCards(identity: card)
        snapshot.mode = mode
        snapshot.energy = energy
        self.init(snapshot: snapshot, night: night)
    }

    /// Hands the model a snapshot in which the character owns `item`, as after a purchase in the shop.
    func own(_ item: HomeItem) {
        var next = snapshot
        next.owned.insert("room.\(item.rawValue)")
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
