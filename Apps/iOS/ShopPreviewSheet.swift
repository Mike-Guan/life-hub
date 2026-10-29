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
                figure
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .toyCard(fill: item.slot.tileColor(for: persona), radius: 16, shadow: 0)
                    .accessibilityHidden(true)
                if let whereShown {
                    Text(whereShown)
                        .font(Toy.body(13, weight: .bold))
                }
                // UI 二组 地毯两款 v1.
                if item.isRug {
                    Text("原来的款式留着，在家里随时换回。".localized)
                        .font(Toy.body(13))
                        .foregroundStyle(Toy.muted)
                }
                // 商店完整目录 §10.2: owning gear is not training.
                if item.zone?.isSports == true {
                    Text("摆着不算练过，不给罐子。")
                        .font(Toy.body(13))
                        .foregroundStyle(Toy.muted)
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

    // UI 审核 (#476): in the app the character always moves, so the preview breathes and blinks like the unboxing.
    @ViewBuilder private var figure: some View {
        // UI 审核 2026-10-17: a room item shows in the real room, where it stands, circled. Items the home page
        // doesn't draw yet (the second preset character's) show their icon.
        if item.slot == .room {
            if let room = HomeItemPreview(itemID: item.id) {
                room.frame(width: 260, height: 260)
            } else {
                ShopItemIcon(item: item)
                    .frame(width: 160, height: 160)
            }
        } else if persona == .kuro {
            KuroView(
                look: KuroLook(mode: shownMode, card: card),
                wearing: wearing.worn(in: shownMode),
                showsBubble: false
            )
        } else {
            CompanionView(mode: shownMode, card: card, wardrobe: wearing, showsBubble: false, notices: false)
        }
    }

    private var cards: ModeCards { ModeCards.current(in: AppGroup.defaults, persona: persona) }
    private var card: IdentityKind? { cards.identity }

    // Mike 2026-10-15: without this line he'd assume an item shows in every mode.
    /// Which modes the item shows in, by the user's card names; `nil` when it shows in all of them.
    private var whereShown: String? {
        if let zone = item.zone { return zone.place }
        if item.isRug { return "换掉家里的地毯款式。颜色在家里免费换。".localized }
        let modes = Mode.allCases.filter { mode in
            if let kuro = KuroItem(rawValue: item.id) { return kuro.shows(in: KuroLook(mode: mode, card: card)) }
            return item.shows(in: mode, card: card)
        }
        guard !modes.isEmpty, modes.count < Mode.allCases.count else { return nil }
        // UI 审核 (#476): 「」 are Chinese and Japanese quotes; English lists the names with "and".
        let titles = modes.map { cards.title(for: $0, persona: persona) }
        let names: String
        if Languages.locale.language.languageCode == .english {
            let list = ListFormatter()
            list.locale = Languages.locale
            names = list.string(from: titles.map { "“\($0)”" }) ?? titles.joined(separator: ", ")
        } else {
            names = titles.map { "「\($0)」" }.joined()
        }
        return String(format: "只在 %@ 出现".localized, names)
    }

    private var wearing: Wardrobe {
        var copy = wardrobe
        copy.equip(item)
        return copy
    }

    private var shownMode: Mode { item.previewMode(current: mode, card: card) }

    private func button(_ title: LocalizedStringKey, fill: Color, action: @escaping () -> Void) -> some View {
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

extension RoomZone {
    // UI 二组 商店两栏 v1.1: where a room item stands, in place of the modes it shows in.
    /// Where in the home page the zone's items stand.
    var place: String {
        let text =
            switch self {
            case .sportFloor: "摆在家里的运动角，靠墙。哪个模式都在。"
            case .sportWall: "靠在家里的运动墙上。哪个模式都在。"
            case .desk: "摆在家里的书桌上。哪个模式都在。"
            case .sofaSide: "摆在家里的沙发旁边。哪个模式都在。"
            case .corner: "摆在家里的左前角。哪个模式都在。"
            case .posterWall: "挂在家里书桌上方的墙上，换掉原来那两张海报。哪个模式都在。"
            }
        return text.localized
    }
}
