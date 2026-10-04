import CompanionKit
import HubCore
import SwiftUI

/// The wardrobe: what HAKU wears in each slot, from the items Mike owns.
struct WardrobeView: View {
    let growth: GrowthStore
    @Binding var wardrobe: Wardrobe
    @Environment(\.dismiss) private var dismiss
    @State private var previewMode: Mode
    @State private var slot: Slot = .gloves

    /// - Parameter mode: the mode to preview first, usually the current one.
    init(growth: GrowthStore, wardrobe: Binding<Wardrobe>, mode: Mode?) {
        self.growth = growth
        _wardrobe = wardrobe
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
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(Toy.ink)
        .background(Toy.paper.ignoresSafeArea())
    }

    private var owned: Set<String> { growth.ledger.owned }

    private var ownedItems: [ShopItem] {
        ShopItem.catalog.filter { $0.slot == slot && owned.contains($0.id) }
    }

    private var lockedKeepsakes: [ShopItem] {
        ShopItem.catalog.filter { item in
            guard item.slot == slot, let keepsake = item.keepsake, !owned.contains(item.id) else { return false }
            return ShopView.liveWins.contains(keepsake.win)
        }
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
            CanChip(count: growth.ledger.balance)
        }
    }

    private var preview: some View {
        CompanionPortrait(mode: previewMode, wardrobe: wardrobe)
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
            .toyCard(fill: previewMode.color)
    }

    // Only changes the preview, never the real mode.
    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(Mode.allCases, id: \.self) { mode in
                Button {
                    previewMode = mode
                } label: {
                    Text(mode.code)
                        .font(Toy.body(13, weight: .heavy))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(ToyButtonStyle(fill: mode.color, isSelected: previewMode == mode))
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
                    Text(tab.title)
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
                WardrobeItemIcon(slotDefault: slot)
                    .frame(width: 56, height: 56)
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
        } label: {
            tile(isWorn: isWorn) {
                WardrobeItemIcon(item: item)
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
        let count = keepsake.map { min(growth.ledger.count($0.win), $0.count) } ?? 0
        return VStack(spacing: 6) {
            WardrobeItemIcon(item: item)
                .frame(width: 56, height: 56)
                .opacity(0.25)
            Text(item.title)
                .font(Toy.body(13, weight: .heavy))
            Text("\(keepsake?.win.shopTitle ?? "") \(count)/\(keepsake?.count ?? 1)")
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
    /// The slot's name on its tab.
    var title: String {
        switch self {
        case .gloves: "拳套"
        case .headband: "头带"
        case .mask: "面罩"
        case .room: "房间"
        case .celebration: "庆祝"
        }
    }
}
