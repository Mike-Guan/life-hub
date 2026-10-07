import CompanionKit
import HubCore
import SwiftUI

/// The wardrobe: what `persona` wears in each slot, from her items Mike owns.
struct WardrobeView: View {
    let growth: GrowthStore
    @Binding var wardrobe: Wardrobe
    let persona: Persona
    @Environment(\.dismiss) private var dismiss
    @State private var previewMode: Mode
    @State private var slot: Slot = .gloves

    /// - Parameters:
    ///   - persona: the character whose wardrobe it is.
    ///   - mode: the mode to preview first, usually the current one.
    init(growth: GrowthStore, wardrobe: Binding<Wardrobe>, persona: Persona, mode: Mode?) {
        self.growth = growth
        _wardrobe = wardrobe
        self.persona = persona
        _previewMode = State(initialValue: mode ?? .chill)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                preview
                modePicker
                slotTabs
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    defaultTile
                    ForEach(ownedItems) { item in
                        itemTile(item)
                    }
                    ForEach(lockedKeepsakes) { item in
                        lockedTile(item)
                    }
                }
                Text("点一下就换上。拿到的东西永远在这，不会丢。")
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

    private var ownedItems: [ShopItem] {
        ShopItem.catalog(for: persona).filter { $0.slot == slot && owned.contains($0.id) }
    }

    private var lockedKeepsakes: [ShopItem] {
        ShopItem.catalog(for: persona).filter { item in
            guard item.slot == slot, let keepsake = item.keepsake, !owned.contains(item.id) else { return false }
            return ShopView.liveWins.contains(keepsake.win)
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

    /// "2026-11-02 · 累计 10 次周日拳击": when and how a keepsake was earned.
    private func earnedLine(_ item: ShopItem, at date: Date) -> String {
        let day = date.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        guard let keepsake = item.keepsake else { return day }
        return "\(day) · 累计 \(keepsake.count) 次\(keepsake.win.shopTitle(for: persona))"
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
            Text("衣柜")
                .font(Toy.display(26))
            Spacer()
            CanChip(count: ledger.balance)
        }
    }

    private var preview: some View {
        PersonaPortrait(persona: persona, mode: previewMode, wardrobe: wardrobe)
            .frame(width: 210, height: 276)
            .frame(maxWidth: .infinity, alignment: .bottom)
            .frame(height: 300, alignment: .bottom)
            .overlay(alignment: .bottomLeading) {
                Text("锁屏上也是这样")
                    .font(Toy.body(13, weight: .heavy))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .toyCard(radius: 12, shadow: 0)
                    .padding(12)
            }
            .toyCard(fill: previewMode.color(for: persona))
    }

    // Only changes the preview, never the real mode.
    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(Mode.allCases, id: \.self) { mode in
                Button {
                    previewMode = mode
                } label: {
                    Text(mode.code(for: persona))
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

    private var slotTabs: some View {
        HStack(spacing: 6) {
            ForEach(Slot.allCases, id: \.self) { tab in
                Button {
                    slot = tab
                } label: {
                    Text(tab.title(for: persona))
                        .font(Toy.body(14, weight: .heavy))
                        .foregroundStyle(slot == tab ? Toy.paper : Toy.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(slot == tab ? Toy.ink : Toy.card))
                        .overlay(Capsule().stroke(Toy.ink, lineWidth: Toy.outline))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(slot == tab ? .isSelected : [])
            }
        }
    }

    private var defaultTile: some View {
        let isWorn = wardrobe.equipped[slot] == nil
        return Button {
            wardrobe.clear(slot)
        } label: {
            tile(isWorn: isWorn) {
                // KURO's default is her plain look, so her tile has no icon.
                if persona == .haku {
                    WardrobeItemIcon(slotDefault: slot)
                        .frame(width: 56, height: 56)
                } else {
                    Color.clear
                        .frame(width: 56, height: 56)
                }
                Text(slot == .room ? "无" : "默认")
                    .font(Toy.body(13, weight: .heavy))
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isWorn ? .isSelected : [])
    }

    private func itemTile(_ item: ShopItem) -> some View {
        let isWorn = wardrobe.equipped[slot] == item.id
        return Button {
            wardrobe.equip(item)
            // Her items show only in their own look, so the preview switches to it.
            if let look = KuroItem(rawValue: item.id)?.look {
                previewMode = Mode.allCases.first { KuroLook(mode: $0) == look } ?? previewMode
            }
        } label: {
            tile(isWorn: isWorn) {
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

    private func tile<Content: View>(isWorn: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 6, content: content)
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 128)
            .toyCard(fill: isWorn ? slot.tileColor : Toy.card, radius: 16, shadow: isWorn ? 1 : 4)
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

    private func lockedTile(_ item: ShopItem) -> some View {
        let keepsake = item.keepsake
        let count = keepsake.map { min(ledger.count($0.win), $0.count) } ?? 0
        return VStack(spacing: 6) {
            ShopItemIcon(item: item)
                .frame(width: 56, height: 56)
                .opacity(0.25)
            Text(item.title)
                .font(Toy.body(13, weight: .heavy))
            Text("\(keepsake?.win.shopTitle(for: persona) ?? "") \(count)/\(keepsake?.count ?? 1)")
                .font(Toy.body(11, weight: .bold))
                .foregroundStyle(Toy.muted)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 128)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Toy.muted, style: StrokeStyle(lineWidth: Toy.outline, dash: [6, 4]))
        )
        .accessibilityElement(children: .combine)
    }
}

extension Slot {
    // KURO's items reuse HAKU's slots: her tennis things are gloves, hair ties headbands, the blanket a mask.
    /// The slot's name on `persona`'s tab.
    func title(for persona: Persona) -> String {
        switch self {
        case .gloves: persona == .kuro ? "网球" : "拳套"
        case .headband: persona == .kuro ? "发饰" : "头带"
        case .mask: persona == .kuro ? "毯子" : "面罩"
        case .room: "房间"
        case .celebration: "庆祝"
        }
    }
}
