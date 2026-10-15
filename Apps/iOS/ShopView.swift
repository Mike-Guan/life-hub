import CompanionKit
import HubCore
import SwiftUI

/// The shop for `persona`: her items to buy with cans, what's owned, and the keepsakes still to earn.
struct ShopView: View {
    let growth: GrowthStore
    @Binding var wardrobe: Wardrobe
    let persona: Persona
    @Environment(\.dismiss) private var dismiss
    @State private var buyError: String?
    @State private var unboxing: CanEntry?

    // Wins the app can detect today. Keepsakes and the footer only mention these, so nothing
    // promises a reward the app can't give yet. Add a win here when its source is wired.
    static let liveWins: [Win] = [.boxing, .run5k, .exercise, .daylight, .earlySleep, .steps]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                banner
                Text("上架")
                    .font(Toy.body(15, weight: .heavy))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(forSale) { item in
                        itemCard(item)
                    }
                }
                ForEach(ownedFromShop) { item in
                    ownedRow(item)
                }
                if let buyError {
                    ErrorLine(text: buyError)
                }
                if !keepsakes.isEmpty {
                    Text("纪念品 · 只能靠做到拿")
                        .font(Toy.body(15, weight: .heavy))
                    VStack(spacing: 0) {
                        ForEach(keepsakes) { item in
                            keepsakeRow(item)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .toyCard(radius: 16, shadow: 4)
                }
                Text(footer)
                    .font(Toy.body(12, weight: .bold))
                    .foregroundStyle(Toy.muted)
                    .lineSpacing(4)
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(Toy.ink)
        .background(Toy.paper.ignoresSafeArea())
        .fullScreenCover(item: $unboxing) { entry in
            UnboxCover(entry: entry, wardrobe: $wardrobe, persona: persona)
        }
    }

    // Each character spends and collects with her own cans.
    private var ledger: CanLedger { growth.ledger.only(persona) }
    private var balance: Int { ledger.balance }
    private var owned: Set<String> { ledger.owned }
    // Card items show only with their card. Ones bought under another card stay owned and wearable.
    private var card: IdentityKind? { .picked(for: persona) }

    private var weekly: ShopItem? { ShopItem.weekly(for: persona, ledger: growth.ledger, now: .now) }

    // 商店完整目录 v0 §1.4: this week's item leads the shelf, and stays there marked owned once bought.
    private var forSale: [ShopItem] {
        [weekly].compactMap { $0 }
            + ShopItem.catalog(for: persona, card: card).filter { $0.price != nil && !owned.contains($0.id) }
    }

    private var ownedFromShop: [ShopItem] {
        ShopItem.catalog(for: persona).filter { $0.price != nil && owned.contains($0.id) && $0.id != weekly?.id }
    }

    private var keepsakes: [ShopItem] {
        ShopItem.catalog(for: persona).filter { item in
            guard let keepsake = item.keepsake, item.isDrawn else { return false }
            return (Self.liveWins.contains(keepsake.win) && item.suits(card)) || owned.contains(item.id)
        }
    }

    private var footer: String {
        let wins = Self.liveWins.compactMap { win in
            win.shopTitle(for: persona).map { "\($0) +\(win.cans)" }
        }.joined(separator: "，")
        return "能量罐只靠真的做到才有：\(wins)。不过期，也不会被扣。"
    }

    private var header: some View {
        // A full-screen cover closes with "完成" at the top right, not a back arrow.
        HStack(spacing: 8) {
            Text("商店")
                .font(Toy.display(26))
            Spacer()
            CanChip(count: balance)
            Button {
                dismiss()
            } label: {
                Text("完成")
                    .font(Toy.body(17, weight: .black))
                    .foregroundStyle(Toy.ink)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var banner: some View {
        HStack(alignment: .bottom, spacing: 10) {
            PersonaPortrait(persona: persona, mode: .chill)
                .frame(width: 88, height: 112)
            Text(persona == .kuro ? "……随便看看，不急。" : "看上哪个了？……我只是随便问问。")
                .font(Toy.body(14, weight: .heavy))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .toyCard(radius: 14, shadow: 0)
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 12)
        .frame(height: 118)
        .frame(maxWidth: .infinity, alignment: .leading)
        .toyCard(fill: Mode.chill.color(for: persona))
        .accessibilityElement(children: .combine)
    }

    private func itemCard(_ item: ShopItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ShopItemIcon(item: item)
                .frame(width: 56, height: 56)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .toyCard(fill: item.slot.tileColor(for: persona), radius: 12, shadow: 0)
            Text(item.title)
                .font(Toy.body(14, weight: .heavy))
            if owned.contains(item.id) {
                Label("已拥有", systemImage: "checkmark")
                    .font(Toy.body(13, weight: .heavy))
                    .foregroundStyle(Toy.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else if let price = item.price {
                if price <= balance {
                    Button {
                        buy(item)
                    } label: {
                        Text("\(price) 能量罐 换")
                            .font(Toy.body(15, weight: .heavy))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(ToyButtonStyle(fill: Toy.pink, isSelected: true))
                } else {
                    Text("\(price) 能量罐 · 还差 \(price - balance)")
                        .font(Toy.body(14, weight: .bold))
                        .foregroundStyle(Toy.muted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Toy.muted, style: StrokeStyle(lineWidth: Toy.outline, dash: [6, 4]))
                        )
                }
            }
        }
        .padding(10)
        .toyCard(radius: 16, shadow: 4)
        .overlay(alignment: .topTrailing) {
            // 商店完整目录 v0 §1.4: only this tag, no countdown and no "limited" wording.
            if item.week != nil {
                Text("本周")
                    .font(Toy.body(12, weight: .heavy))
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Capsule().fill(Toy.pink))
                    .overlay(Capsule().stroke(Toy.ink, lineWidth: Toy.outline))
                    .offset(x: 8, y: -10)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.week != nil ? Text("本周 \(item.title)") : Text(verbatim: item.title))
    }

    private func ownedRow(_ item: ShopItem) -> some View {
        HStack(spacing: 10) {
            ShopItemIcon(item: item)
                .frame(width: 32, height: 32)
            Text(item.title)
                .font(Toy.body(14, weight: .heavy))
            Spacer()
            Label("已拥有", systemImage: "checkmark")
                .font(Toy.body(13, weight: .heavy))
                .foregroundStyle(Toy.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .toyCard(radius: 14, shadow: 0)
        .accessibilityElement(children: .combine)
    }

    private func keepsakeRow(_ item: ShopItem) -> some View {
        let isOwned = owned.contains(item.id)
        let keepsake = item.keepsake
        let count = keepsake.map { min(ledger.count($0.win, card: $0.card), $0.count) } ?? 0
        let goal = keepsake?.count ?? 1
        return HStack(spacing: 10) {
            ShopItemIcon(item: item)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                    Spacer()
                    Text(isOwned ? "已拥有" : "\(keepsake?.title(for: persona) ?? "") \(count)/\(goal)")
                        .foregroundStyle(Toy.muted)
                }
                .font(Toy.body(14, weight: .heavy))
                if !isOwned {
                    ProgressView(value: Double(count), total: Double(goal))
                        .tint(item.slot.tileColor(for: persona))
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func buy(_ item: ShopItem) {
        do {
            try growth.buy(item)
            buyError = growth.lastError
            unboxing = ledger.unboxings(seen: UnboxLog.seen, persona: persona).last { $0.itemID == item.id }
        } catch {
            buyError =
                switch error {
                case .notForSale: "这个不卖。"
                case .alreadyOwned: "已经有了。"
                case .notEnoughCans: "能量罐还不够。"
                }
        }
    }
}

extension Win {
    // Issue #279: the identity card's win carries the card's name, so it reads right for every card.
    /// How `persona`'s shop names the win; `nil` for the identity card's win when no card is picked.
    func shopTitle(for persona: Persona) -> String? {
        switch self {
        case .gym: "去健身房"
        case .boxing: IdentityKind.picked(for: persona)?.title
        case .run5k: "跑完 5 km"
        case .gotUp: "被叫起来出门"
        case .daylight: "晒太阳"
        case .earlySleep: "按时睡"
        case .plannedTask: "做完定好的事"
        case .exercise: "运动 30 分钟"
        case .steps: "走了不少路"
        }
    }
}

extension ShopItem.Keepsake {
    /// What the keepsake counts, as `persona`'s shop names it: the card's name for a card's keepsake.
    func title(for persona: Persona) -> String {
        card?.title ?? win.shopTitle(for: persona) ?? ""
    }
}

extension IdentityKind {
    // Until the card editor saves cards (#273), every install keeps its character's card from before.
    /// The identity card the user picked, `nil` when none.
    static func picked(for persona: Persona) -> IdentityKind? {
        (ModeCards.stored(in: AppGroup.defaults) ?? .legacy(for: persona)).identity
    }
}

/// A shop item's icon, drawn the way its character shows it.
struct ShopItemIcon: View {
    let item: ShopItem

    var body: some View {
        if let kuro = KuroItem(rawValue: item.id) {
            KuroItemIcon(item: kuro)
        } else {
            WardrobeItemIcon(item: item)
        }
    }
}

/// `persona` standing still in `mode`'s look, dressed for `card` in the identity card mode, wearing `wardrobe`.
struct PersonaPortrait: View {
    let persona: Persona
    let mode: Mode
    var card: IdentityKind?
    var wardrobe = Wardrobe()

    var body: some View {
        if persona == .kuro {
            KuroPortrait(look: KuroLook(mode: mode, card: card), wearing: wardrobe.worn(in: mode))
        } else {
            CompanionPortrait(mode: mode, card: card, wardrobe: wardrobe)
        }
    }
}
