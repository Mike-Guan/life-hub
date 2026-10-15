import CompanionKit
import HubCore
import SwiftUI

/// The wardrobe: what `persona` wears in each slot, from her items Mike owns.
struct WardrobeView: View {
    let growth: GrowthStore
    @Binding var wardrobe: Wardrobe
    let persona: Persona
    private let cards: ModeCards
    @Environment(\.dismiss) private var dismiss
    @State private var previewMode: Mode
    @State private var shelf: WardrobeShelf = .clothes

    /// - Parameters:
    ///   - persona: the character whose wardrobe it is.
    ///   - mode: the mode to preview first, usually the current one.
    ///   - cards: the user's mode cards, which name the mode buttons; the character's defaults when `nil`.
    ///   - shelf: the tab to show first.
    init(
        growth: GrowthStore,
        wardrobe: Binding<Wardrobe>,
        persona: Persona,
        mode: Mode?,
        cards: ModeCards? = nil,
        shelf: WardrobeShelf = .clothes
    ) {
        self.growth = growth
        _wardrobe = wardrobe
        self.persona = persona
        self.cards = cards ?? .legacy(for: persona)
        _previewMode = State(initialValue: mode ?? .chill)
        _shelf = State(initialValue: shelf)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                preview
                modePicker
                shelfTabs
                grid(defaultSlots: shownShelf.defaultSlots, items: shelfItems)
                // 商店完整目录 §9.1: celebrations are the last group of accessories, shown once one is owned.
                if shownShelf == .accessories && !celebrations.isEmpty {
                    Text("庆祝")
                        .font(Toy.body(15, weight: .black))
                    grid(defaultSlots: [.celebration], items: celebrations)
                }
                Text(shelfNote)
                    .font(Toy.body(13, weight: .bold))
                    .foregroundStyle(Toy.muted)
                if !collection.isEmpty {
                    lifeCollection
                }
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(Toy.ink)
        .background(Toy.paper.ignoresSafeArea())
    }

    // Each character spends and collects with her own cans.
    private var ledger: CanLedger { growth.ledger.only(persona) }
    private var owned: Set<String> { ledger.owned }

    private var card: IdentityKind? { cards.identity }

    // Props leave when the picker moves off the identity card's mode, so the clothes take their place.
    private var shownShelf: WardrobeShelf {
        WardrobeShelf.shelves(in: previewMode, card: card).contains(shelf) ? shelf : .clothes
    }

    // 商店完整目录 §9.3: an unearned keepsake stays hidden, as in the life collection. A keepsake can be earned
    // before its art exists, so it waits until the character draws it.
    private var ownedShowing: [ShopItem] {
        ShopItem.catalog(for: persona).filter {
            owned.contains($0.id) && $0.isDrawn && $0.shows(in: previewMode, card: card)
        }
    }

    private var shelfItems: [ShopItem] {
        ownedShowing.filter { $0.slot.shelf == shownShelf && $0.slot != .celebration }
    }

    private var celebrations: [ShopItem] {
        ownedShowing.filter { $0.slot == .celebration }
    }

    private var shelfNote: String {
        switch shownShelf {
        case .clothes: "只列\(cards.title(for: previewMode, persona: persona))能穿的。拿到的东西永远在这，不会丢。"
        case .accessories: "配饰每个模式都戴。拿到的东西永远在这，不会丢。"
        case .props: "道具只在这张卡的模式里拿着。拿到的东西永远在这，不会丢。"
        case .room: "房间里一次摆一件。拿到的东西永远在这，不会丢。"
        }
    }

    // Keepsakes from every slot, in the order they were earned.
    private var collection: [(item: ShopItem, at: Date)] {
        ShopItem.catalog(for: persona)
            .compactMap { item in
                guard item.keepsake != nil, let at = ledger.ownedAt(item.id) else { return nil }
                return (item, at)
            }
            .sorted { $0.at < $1.at }
    }

    private var lifeCollection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("人生收藏")
                .font(Toy.display(22))
            ForEach(collection, id: \.item.id) { entry in
                HStack(spacing: 12) {
                    ShopItemIcon(item: entry.item)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.item.title)
                            .font(Toy.body(15, weight: .heavy))
                        Text(earnedLine(entry.item, at: entry.at))
                            .font(Toy.body(12, weight: .bold))
                            .foregroundStyle(Toy.muted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .toyCard(radius: 16, shadow: 2)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, 8)
    }

    /// "2026-11-02 · 累计 10 次拳击日": when and how a keepsake was earned.
    private func earnedLine(_ item: ShopItem, at date: Date) -> String {
        let day = date.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        guard let keepsake = item.keepsake else { return day }
        return "\(day) · 累计 \(keepsake.count) 次\(keepsake.title(for: persona))"
    }

    private var header: some View {
        // A full-screen cover closes with "完成" at the top right, not a back arrow.
        HStack(spacing: 8) {
            Text("衣柜")
                .font(Toy.display(26))
            Spacer()
            CanChip(count: ledger.balance)
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

    // UI 审核 R1: a label on the card covered the gloves, so it sits under the card.
    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            PersonaPortrait(persona: persona, mode: previewMode, card: card, wardrobe: wardrobe.showing(card: card))
                .frame(width: 210, height: 276)
                .frame(maxWidth: .infinity, alignment: .bottom)
                .frame(height: 300, alignment: .bottom)
                .toyCard(fill: previewMode.color(for: persona))
            Text("锁屏上也是这样")
                .font(Toy.body(13, weight: .heavy))
                .foregroundStyle(Toy.muted)
        }
    }

    // Only changes the preview, never the real mode.
    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(cards.modes, id: \.self) { mode in
                Button {
                    previewMode = mode
                } label: {
                    Text(cards.title(for: mode, persona: persona))
                        .font(Toy.body(13, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(ToyButtonStyle(fill: mode.color(for: persona), isSelected: previewMode == mode))
                .accessibilityAddTraits(previewMode == mode ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("看哪个模式的样子")
    }

    private var shelfTabs: some View {
        HStack(spacing: 6) {
            ForEach(WardrobeShelf.shelves(in: previewMode, card: card), id: \.self) { tab in
                Button {
                    shelf = tab
                } label: {
                    Text(tab.title)
                        .font(Toy.body(14, weight: .heavy))
                        .foregroundStyle(shownShelf == tab ? Toy.paper : Toy.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(shownShelf == tab ? Toy.ink : Toy.card))
                        .overlay(Capsule().stroke(Toy.ink, lineWidth: Toy.outline))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(shownShelf == tab ? .isSelected : [])
            }
        }
    }

    private func grid(defaultSlots: [Slot], items: [ShopItem]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            defaultTile(defaultSlots)
            ForEach(items) { item in
                itemTile(item)
            }
        }
    }

    // The default tile takes off what the shelf's items put on: the mode's clothes, or the listed slots.
    private func defaultTile(_ slots: [Slot]) -> some View {
        let clothes = slots == [.top]
        let isWorn = clothes ? wardrobe.clothes[previewMode] == nil : slots.allSatisfy { wardrobe.equipped[$0] == nil }
        let slot = slots[0]
        return Button {
            if clothes {
                wardrobe.undress(previewMode)
            } else {
                slots.forEach { wardrobe.clear($0) }
            }
        } label: {
            tile(isWorn: isWorn, fill: slot.tileColor(for: persona)) {
                // KURO has no default item to wear, so her worn slots show her head without this shelf's items.
                // HAKU's default clothes have no item picture either, so they show his head the same way.
                // Room and celebration are not worn, so they show the same picture for both.
                if slot == .room || slot == .celebration || (persona == .haku && !clothes) {
                    WardrobeItemIcon(slotDefault: slot)
                        .frame(width: 56, height: 56)
                } else if persona == .haku {
                    CompanionPortrait(
                        mode: previewMode, card: card, wardrobe: wardrobe.showing(card: card), idles: false,
                        framing: .head
                    )
                    .frame(width: 56, height: 56)
                } else {
                    KuroPortrait(look: KuroLook(mode: previewMode, card: card), wearing: without(slots), framing: .head)
                        .frame(width: 56, height: 56)
                }
                Text(slot == .room ? "无" : "默认")
                    .font(Toy.body(13, weight: .heavy))
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isWorn ? .isSelected : [])
    }

    private func without(_ slots: [Slot]) -> Set<String> {
        var plain = wardrobe.showing(card: card)
        // The clothes default tile takes off the previewed mode's top or set.
        slots.forEach { $0.shelf == .clothes ? plain.undress(previewMode) : plain.clear($0) }
        return plain.worn(in: previewMode)
    }

    private func itemTile(_ item: ShopItem) -> some View {
        let isWorn = wardrobe.isWearing(item)
        return Button {
            wardrobe.equip(item)
            // Her items show only in their own look, so the preview switches to it.
            if let look = KuroItem(rawValue: item.id)?.look {
                previewMode = Mode.allCases.first { KuroLook(mode: $0, card: card) == look } ?? previewMode
            }
        } label: {
            tile(isWorn: isWorn, fill: item.slot.tileColor(for: persona)) {
                ShopItemIcon(item: item)
                    .frame(width: 56, height: 56)
                Text(item.title)
                    .font(Toy.body(13, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isWorn ? .isSelected : [])
    }

    private func tile<Content: View>(isWorn: Bool, fill: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 6, content: content)
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 128)
            .toyCard(fill: isWorn ? fill : Toy.card, radius: 16, shadow: isWorn ? 1 : 4)
            .overlay(alignment: .topTrailing) {
                if isWorn {
                    Text("穿着")
                        .font(Toy.body(12, weight: .heavy))
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(Capsule().fill(Toy.pink))
                        .overlay(Capsule().stroke(Toy.ink, lineWidth: Toy.outline))
                        .offset(x: 8, y: -10)
                }
            }
    }
}

extension WardrobeShelf {
    /// The shelf's name on its tab.
    var title: String {
        switch self {
        case .clothes: "衣服"
        case .accessories: "配饰"
        case .props: "道具"
        case .room: "房间"
        }
    }

    // KURO's items reuse HAKU's slots: her hair ties are headbands, her blanket the mask.
    /// The slots the shelf's default tile takes off.
    var defaultSlots: [Slot] {
        switch self {
        case .clothes: [.top]
        case .accessories: [.headband, .mask, .badge, .hat]
        case .props: [.gloves]
        case .room: [.room]
        }
    }
}
