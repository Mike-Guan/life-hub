import HubCore
import SwiftUI

// Used by scripts/screenshots.sh to draw the shop, wardrobe and unboxing for UI 审核. Debug builds only.
// Everything lives in memory: ten identity-card wins and one 5 km run, then the first item bought.
/// The shop, the wardrobe or a keepsake's unboxing for `ScreenshotMode.persona`, picked by `screen`.
/// `unbox-bottom` opens the unboxing scrolled down to its buttons; `wardrobe-<shelf>` opens the wardrobe on that tab.
struct ScreenshotGrowth: View {
    let screen: String
    @State private var growth = Self.growth()
    @State private var wardrobe = Wardrobe()

    var body: some View {
        switch screen {
        case "wardrobe", "wardrobe-accessories", "wardrobe-props", "wardrobe-room":
            WardrobeView(
                growth: growth,
                wardrobe: $wardrobe,
                persona: ScreenshotMode.persona,
                mode: .boxing,
                cards: ScreenshotMode.cards,
                shelf: WardrobeShelf(rawValue: String(screen.dropFirst("wardrobe-".count))) ?? .clothes
            )
        case "unbox", "unbox-bottom":
            if let entry = growth.ledger.entries.first(where: { $0.kind == .granted }),
                let item = entry.itemID.flatMap(ShopItem.item)
            {
                UnboxSheet(
                    entry: entry,
                    item: item,
                    wardrobe: $wardrobe,
                    persona: ScreenshotMode.persona,
                    startsAtBottom: screen == "unbox-bottom"
                )
            }
        case "shop-room":
            ShopView(growth: growth, wardrobe: $wardrobe, persona: ScreenshotMode.persona, shelf: .room)
        case "shop-room-preview":
            if let item = ShopItem.catalog(for: ScreenshotMode.persona).first(where: { $0.id == "room.bench" }) ?? ShopItem.catalog(for: ScreenshotMode.persona).first(where: { $0.slot == .room && $0.price != nil }) {
                ZStack {
                    ShopView(growth: growth, wardrobe: $wardrobe, persona: ScreenshotMode.persona, shelf: .room)
                    ShopPreviewSheet(
                        item: item, persona: ScreenshotMode.persona, wardrobe: wardrobe, balance: 99,
                        onCancel: {}, onBuy: {})
                }
            }
        default:
            ShopView(growth: growth, wardrobe: $wardrobe, persona: ScreenshotMode.persona)
        }
    }

    private static func growth() -> GrowthStore {
        let persona = ScreenshotMode.persona
        let growth = GrowthStore(fileURL: nil, deviceID: "screenshot")
        growth.persona = persona
        let day: TimeInterval = 24 * 3600
        for index in 0..<10 {
            growth.record(.boxing, source: "card-\(index)", at: .now.addingTimeInterval(-Double(70 - 7 * index) * day))
        }
        growth.record(.run5k, source: "run-0", at: .now.addingTimeInterval(-3 * day))
        if let first = ShopItem.catalog(for: persona).first(where: { $0.price != nil }) {
            try? growth.buy(first)
        }
        return growth
    }
}
