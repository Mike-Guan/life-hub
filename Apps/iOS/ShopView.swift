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
    static let liveWins: [Win] = [.boxing, .run5k, .gym]

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

    private var forSale: [ShopItem] {
        ShopItem.catalog(for: persona).filter { $0.price != nil && !owned.contains($0.id) }
    }

    private var ownedFromShop: [ShopItem] {
        ShopItem.catalog(for: persona).filter { $0.price != nil && owned.contains($0.id) }
    }

    private var keepsakes: [ShopItem] {
        ShopItem.catalog(for: persona).filter { item in
            guard let keepsake = item.keepsake else { return false }
            return Self.liveWins.contains(keepsake.win) || owned.contains(item.id)
        }
    }

    private var footer: String {
        let wins = Self.liveWins.map { "\($0.shopTitle(for: persona)) +\($0.cans)" }.joined(separator: "，")
        return "能量罐只靠真的做到才有：\(wins)。不过期，也不会被扣。"
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(Toy.body(20, weight: .heavy))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")
            Text("商店")
                .font(Toy.display(26))
            Spacer()
            CanChip(count: balance)
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
            if let price = item.price {
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.title)
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
        let count = keepsake.map { min(ledger.count($0.win), $0.count) } ?? 0
        let goal = keepsake?.count ?? 1
        return HStack(spacing: 10) {
            ShopItemIcon(item: item)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                    Spacer()
                    Text(isOwned ? "已拥有" : "\(keepsake?.win.shopTitle(for: persona) ?? "") \(count)/\(goal)")
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
    /// How `persona`'s shop names the win.
    func shopTitle(for persona: Persona) -> String {
        switch self {
        case .gym: "健身"
        case .boxing: persona == .kuro ? "网球日" : "周日拳击"
        case .run5k: "跑完 5 km"
        case .gotUp: "被叫起来出门"
        case .daylight: "晒太阳"
        case .earlySleep: "按时睡"
        case .plannedTask: "做完定好的事"
        }
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

/// `persona` standing still in `mode`'s look, wearing `wardrobe`.
struct PersonaPortrait: View {
    let persona: Persona
    let mode: Mode
    var wardrobe = Wardrobe()

    var body: some View {
        if persona == .kuro {
            KuroPortrait(look: KuroLook(mode: mode), wearing: Set(wardrobe.equipped.values))
        } else {
            CompanionPortrait(mode: mode, wardrobe: wardrobe)
        }
    }
}
