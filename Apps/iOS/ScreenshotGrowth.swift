import HubCore
import SwiftUI

// Used by scripts/screenshots.sh to draw the shop, wardrobe and unboxing for UI 审核. Debug builds only.
// Everything lives in memory: ten identity-card wins and one 5 km run, then the first item bought.
/// The shop, the wardrobe or a keepsake's unboxing for `ScreenshotMode.persona`, picked by `screen`.
/// `unbox-bottom` opens the unboxing scrolled down to its buttons.
struct ScreenshotGrowth: View {
    let screen: String
    @State private var growth = Self.growth()
    @State private var wardrobe = Wardrobe()

    var body: some View {
        switch screen {
        case "wardrobe":
            WardrobeView(
                growth: growth,
                wardrobe: $wardrobe,
                persona: ScreenshotMode.persona,
                mode: .boxing,
                cards: ScreenshotMode.cards
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
