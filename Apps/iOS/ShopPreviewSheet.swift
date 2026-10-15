import CompanionKit
import HubCore
import SwiftUI

// Mike 2026-10-14 01:46Z: the shop list keeps its small icons; tapping one shows the character wearing it, and
// only the confirm button spends cans (Mike 2026-10-15: a tap used to buy at once).
/// Shows `item` worn before buying it, with the price and a confirm button.
struct ShopPreviewSheet: View {
    let item: ShopItem
    let persona: Persona
    let wardrobe: Wardrobe
    let balance: Int
    /// The current mode, so the character shows it when the item shows there.
    var mode: Mode?
    let onCancel: () -> Void
    let onBuy: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Toy.ink.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 12) {
                Text(item.title)
                    .font(Toy.body(17, weight: .heavy))
                PersonaPortrait(persona: persona, mode: shownMode, card: card, wardrobe: wearing)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .toyCard(fill: item.slot.tileColor(for: persona), radius: 16, shadow: 0)
                    .accessibilityHidden(true)
                if let whereShown {
                    Text(whereShown)
                        .font(Toy.body(13, weight: .bold))
                }
                if let price = item.price, price > balance {
                    Text("\(price) 能量罐 · 还差 \(price - balance)")
                        .font(Toy.body(13))
                        .foregroundStyle(Toy.muted)
                }
                HStack(spacing: 12) {
                    button("再想想", fill: Toy.card, action: onCancel)
                    if let price = item.price, price <= balance {
                        button("\(price) 能量罐 换", fill: Toy.pink, action: onBuy)
                    }
                }
            }
            .foregroundStyle(Toy.ink)
            .frame(maxWidth: 560, alignment: .leading)
            .padding(18)
            .toyCard(radius: 22, shadow: 5)
            .padding(12)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, onCancel)
        }
    }

    private var cards: ModeCards { ModeCards.current(in: AppGroup.defaults, persona: persona) }
    private var card: IdentityKind? { cards.identity }

    // Mike 2026-10-15: without this line he'd assume an item shows in every mode.
    /// Which modes the item shows in, by the user's card names; `nil` when it shows in all of them.
    private var whereShown: String? {
        let modes = Mode.allCases.filter { mode in
            if let kuro = KuroItem(rawValue: item.id) { return kuro.shows(in: KuroLook(mode: mode, card: card)) }
            return item.shows(in: mode, card: card)
        }
        guard !modes.isEmpty, modes.count < Mode.allCases.count else { return nil }
        let names = modes.map { "「\(cards.title(for: $0, persona: persona))」" }.joined(separator: "")
        return String(format: "只在 %@ 出现".localized, names)
    }

    private var wearing: Wardrobe {
        var copy = wardrobe
        copy.equip(item)
        return copy
    }

    private var shownMode: Mode { item.previewMode(current: mode, card: card) }

    private func button(_ title: String, fill: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Toy.body(15, weight: .heavy))
                .frame(maxWidth: .infinity, minHeight: 48)
                .toyCard(fill: fill, radius: 12, shadow: 3)
        }
        .buttonStyle(.plain)
    }
}

extension ShopItem {
    // Friends test (写死作息 #3): HAKU wears the look of the mode it is in and of the user's own card; an item
    // that doesn't show there falls back to its own mode. The second preset character's items show in their look.
    /// The mode to show the item in, given the `current` mode and the user's `card`.
    func previewMode(current: Mode?, card: IdentityKind?) -> Mode {
        if let kuro = KuroItem(rawValue: id) {
            return mode ?? Mode.allCases.first { KuroLook(mode: $0) == kuro.look } ?? .chill
        }
        if let current, shows(in: current, card: card) { return current }
        let own = mode ?? slot.showcaseMode
        // Without a card the identity slot is the old boxing kit, so the item shows in Chill instead.
        return own == .boxing && card == nil ? .chill : own
    }
}
