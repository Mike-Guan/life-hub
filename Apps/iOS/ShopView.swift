import CompanionKit
import HubCore
import SwiftUI

/// The shop's two shelves.
enum ShopShelf: CaseIterable {
    case clothes, room

    /// The shelf's name on its tab.
    var title: LocalizedStringKey {
        switch self {
        case .clothes: "衣服"
        case .room: "房间"
        }
    }

    /// Whether `item` is on this shelf.
    func holds(_ item: ShopItem) -> Bool { (item.slot == .room) == (self == .room) }
}

/// A section of the shop's room shelf, in the order the home is laid out.
// UI 二组 2026-10-28: rugs and the poster wall come first.
enum RoomSection: CaseIterable {
    case rug, wall, desk, sofaSide, corner, sports

    /// The section's title over its items.
    var title: LocalizedStringKey {
        switch self {
        case .rug: "地毯"
        case .wall: "墙上"
        case .desk: "书桌上"
        case .sofaSide: "沙发旁"
        case .corner: "角落"
        case .sports: "运动"
        }
    }

    /// Whether `item` is in this section; the sports floor and wall share one.
    func holds(_ item: ShopItem) -> Bool {
        if self == .rug { return item.isRug }
        guard let zone = item.zone else { return false }
        return switch self {
        case .rug: false
        case .wall: zone == .posterWall
        case .desk: zone == .desk
        case .sofaSide: zone == .sofaSide
        case .corner: zone == .corner
        case .sports: zone.isSports
        }
    }
}

/// The shop for `persona`: her items to buy with cans, what's owned, and the keepsakes still to earn.
struct ShopView: View {
    let growth: GrowthStore
    @Binding var wardrobe: Wardrobe
    let persona: Persona
    /// The current mode, for the unboxing.
    var mode: Mode?
    @Environment(\.dismiss) private var dismiss
    @State private var buyError: String?
    @State private var unboxing: CanEntry?
    /// The room items the last purchase put in the cupboard, for the unboxing's line.
    @State private var putAway: [String] = []
    @State private var previewing: ShopItem?
    @State private var shelf: ShopShelf
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 商店与家 同步方案 §1: the home screen's door opens the clothes, the home page's door the room.
    /// - Parameter shelf: the shelf to show first.
    init(
        growth: GrowthStore,
        wardrobe: Binding<Wardrobe>,
        persona: Persona,
        mode: Mode? = nil,
        shelf: ShopShelf = .clothes
    ) {
        self.growth = growth
        _wardrobe = wardrobe
        self.persona = persona
        self.mode = mode
        _shelf = State(initialValue: shelf)
    }

    // Wins the app can detect today. The footer only mentions these, so nothing
    // promises a reward the app can't give yet. Add a win here when its source is wired.
    static let liveWins: [Win] = [.boxing, .run5k, .exercise, .daylight, .earlySleep, .steps]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                shelfTabs
                banner
                // 界面空状态与报错 §2: with no cans yet, how to earn them comes first instead of at the bottom.
                if balance == 0 {
                    howToEarn
                }
                Text("上架")
                    .font(Toy.body(15, weight: .heavy))
                if forSale.isEmpty {
                    allBought
                } else if shelf == .room {
                    roomShelf(roomGroups)
                } else {
                    grid(forSale)
                }
                ForEach(ownedFromShop) { item in
                    ownedRow(item)
                }
                if let buyError {
                    ErrorLine(text: buyError)
                }
                if balance > 0 {
                    Text(footer)
                        .font(Toy.body(12, weight: .bold))
                        .foregroundStyle(Toy.muted)
                        .lineSpacing(4)
                }
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            // 动态: the shelf's items fade over 0.2 s when the tab changes.
            .animation(fade, value: shelf)
        }
        .foregroundStyle(Toy.ink)
        .background(Toy.paper.ignoresSafeArea())
        .overlay {
            if let item = previewing {
                ShopPreviewSheet(
                    item: item,
                    persona: persona,
                    wardrobe: wardrobe,
                    balance: balance,
                    mode: mode,
                    onCancel: { previewing = nil },
                    onBuy: {
                        previewing = nil
                        buy(item)
                    }
                )
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: previewing?.id)
        .fullScreenCover(item: $unboxing) { entry in
            UnboxCover(entry: entry, wardrobe: $wardrobe, persona: persona, mode: mode, putAway: putAway)
        }
    }

    // Each character spends and collects with her own cans.
    private var ledger: CanLedger { growth.ledger.only(persona) }
    private var balance: Int { ledger.balance }
    private var owned: Set<String> { ledger.owned }
    // Card items show only with their card. Ones bought under another card stay owned and wearable.
    private var card: IdentityKind? { .picked(for: persona) }

    private var weekly: ShopItem? { ShopItem.weekly(for: persona, ledger: growth.ledger, now: .now) }

    private var fade: Animation? { reduceMotion ? nil : .smooth(duration: 0.2) }

    // 商店完整目录 v0 §1.4: this week's item leads its shelf, and stays there marked owned once bought.
    private var forSale: [ShopItem] {
        var items = [weekly].compactMap { $0 }
        items += ShopItem.catalog(for: persona, card: card).filter { $0.price != nil && !owned.contains($0.id) }
        return items.filter(shelf.holds)
    }

    // UI 二组 地毯两款 v1 (UI 审核 2026-10-27): the room shelf goes by the home's zones, this week's item first
    // with no title.
    private var roomGroups: [(title: LocalizedStringKey?, items: [ShopItem])] {
        var rest = forSale
        var groups: [(title: LocalizedStringKey?, items: [ShopItem])] = []
        if let weekly, rest.first?.id == weekly.id {
            groups.append((nil, [rest.removeFirst()]))
        }
        for section in RoomSection.allCases {
            let here = rest.filter(section.holds)
            if !here.isEmpty { groups.append((section.title, here)) }
        }
        let unzoned = rest.filter { item in !RoomSection.allCases.contains { $0.holds(item) } }
        if !unzoned.isEmpty { groups.append((nil, unzoned)) }
        return groups
    }

    private var ownedFromShop: [ShopItem] {
        ShopItem.catalog(for: persona)
            .filter { $0.price != nil && owned.contains($0.id) && $0.id != weekly?.id && shelf.holds($0) }
    }

    // The user's own names for the modes and the identity card.
    private var cards: ModeCards { ModeCards.current(in: AppGroup.defaults, persona: persona) }

    // 奖励数值表 §2: the identity card's win reads with the user's name for the card, and is left out without one.
    private var footer: String {
        let wins = Self.liveWins.compactMap { win in
            guard win == .boxing else { return win.shopTitle(for: persona).map { "\($0) +\(win.cans)" } }
            guard cards.identity != nil else { return nil }
            return "\(cards.title(for: .boxing, persona: persona)) 那天 +\(win.cans)（每周一次）"
        }.joined(separator: "，")
        return "能量罐只靠真的做到才有：\(wins)。不过期，也不会被扣。"
    }

    private var howToEarn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("怎么拿罐子")
                .font(Toy.body(15, weight: .heavy))
            Text(footer)
                .font(Toy.body(12.5, weight: .bold))
                .lineSpacing(4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .toyCard(fill: Toy.paper)
        .accessibilityElement(children: .combine)
    }

    // 界面空状态与报错 §1: everything on the shelf is owned. Text only, nothing to tap.
    private var allBought: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("上架的都换到了")
                .font(Toy.body(15, weight: .heavy))
            Text("罐子会一直留着。每周会有一件本周款。")
                .font(Toy.body(12.5, weight: .bold))
                .foregroundStyle(Toy.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .toyCard()
        .accessibilityElement(children: .combine)
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

    // UI 二组 商店两栏 v1.1: the wardrobe's tabs. Mike 2026-10-17: the sliding fill felt slow, so the tapped tab
    // turns black at once (静态: a tab is a switch, not a move) while the shelf below still fades.
    private var shelfTabs: some View {
        HStack(spacing: 6) {
            ForEach(ShopShelf.allCases, id: \.self) { tab in
                Button {
                    shelf = tab
                } label: {
                    Text(tab.title)
                        .font(Toy.body(14, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(shelf == tab ? Toy.paper : Toy.ink)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if shelf == tab {
                                Capsule().fill(Toy.ink)
                            } else {
                                Capsule().fill(Toy.card)
                            }
                        }
                        .overlay(Capsule().stroke(Toy.ink, lineWidth: Toy.outline))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(shelf == tab ? .isSelected : [])
            }
        }
        .transaction { $0.animation = nil }
    }

    private var banner: some View {
        HStack(alignment: .bottom, spacing: 10) {
            PersonaPortrait(persona: persona, mode: .chill)
                .frame(width: 88, height: 112)
            // UI 审核 2026-10-17: the line breaks after the question, so 「问。」 doesn't sit alone.
            Text(persona == .kuro ? "……随便看看，不急。" : "看上哪个了？\n……我只是随便问问。")
                .font(Toy.body(14, weight: .heavy))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .toyCard(radius: 14, shadow: 0)
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 118)
        .frame(maxWidth: .infinity, alignment: .leading)
        .toyCard(fill: Mode.chill.color(for: persona))
        .accessibilityElement(children: .combine)
    }

    private func roomShelf(_ groups: [(title: LocalizedStringKey?, items: [ShopItem])]) -> some View {
        ForEach(groups.indices, id: \.self) { i in
            if let title = groups[i].title {
                Text(title)
                    .font(Toy.body(13, weight: .black))
                    .foregroundStyle(Toy.muted)
                    .accessibilityAddTraits(.isHeader)
            }
            grid(groups[i].items)
        }
    }

    private func grid(_ items: [ShopItem]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            ForEach(items) { item in
                itemCard(item)
            }
        }
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
                        previewing = item
                    } label: {
                        Text("\(price) 能量罐 换")
                            .font(Toy.body(15, weight: .heavy))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(ToyButtonStyle(fill: Toy.pink, isSelected: true))
                    .accessibilityLabel("用 \(price) 个能量罐换\(item.title)")
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
        .overlay(alignment: .topLeading) {
            // 界面空状态与报错 §3: clothes say which mode wears them, in that mode's color and the user's name for it.
            if let mode = item.mode {
                Text("\(cards.title(for: mode, persona: persona))穿")
                    .font(Toy.body(12, weight: .heavy))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Capsule().fill(mode.color(for: persona)))
                    .overlay(Capsule().stroke(Toy.ink, lineWidth: Toy.outline))
                    .padding(.horizontal, 8)
                    .offset(y: -10)
            }
        }
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
        .accessibilityLabel(item.week != nil ? String(format: "本周 %@".localized, item.title) : item.title)
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

    private func buy(_ item: ShopItem) {
        // 动态: the can count rolls down and the bought tile leaves smoothly, without a bounce.
        var failure: GrowthStore.BuyError?
        withAnimation(reduceMotion ? nil : .smooth) {
            do throws(GrowthStore.BuyError) {
                try growth.buy(item)
            } catch {
                failure = error
            }
        }
        if let failure {
            buyError =
                switch failure {
                case .notForSale: "这个不卖。"
                case .alreadyOwned: "已经有了。"
                case .notEnoughCans: "能量罐还不够。"
                }
            return
        }
        buyError = growth.lastError
        // A failed save stays on screen; the unboxing, still unseen, plays when the shop closes.
        guard buyError == nil else { return }
        putAway = item.slot == .room ? RoomLayout.placeBought(item.id, persona: persona, in: AppGroup.defaults) : []
        unboxing = ledger.unboxings(seen: UnboxLog.seen, persona: persona).last { $0.itemID == item.id }
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
    // Launch saves the cards (ModeCards.adopt), so unreadable cards mean no card, never the character's old one.
    /// The identity card the user picked, `nil` when none.
    static func picked(for persona: Persona) -> IdentityKind? {
        ModeCards.current(in: AppGroup.defaults, persona: persona).identity
    }
}
