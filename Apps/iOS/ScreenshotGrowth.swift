import CompanionKit
import HubCore
import SwiftUI

// Used by scripts/screenshots.sh to draw the shop, wardrobe and unboxing for UI 审核. Debug builds only.
// Everything lives in memory: ten identity-card wins and one 5 km run, then the first item bought.
/// The shop, the wardrobe or a keepsake's unboxing for `ScreenshotMode.persona`, picked by `screen`.
/// `unbox-bottom` opens the unboxing scrolled down to its buttons; `wardrobe-<shelf>` opens the wardrobe on that tab.
/// `shop-room` opens the shop on the room tab, `preview-rug` the striped rug's preview, and `home-decorate` the
/// home's 家具换颜色 panel with the striped rug bought.
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
        case "preview-rug":
            if let rug = ShopItem.item(Self.stripedRug) {
                ShopPreviewSheet(
                    item: rug, persona: ScreenshotMode.persona, wardrobe: wardrobe, balance: 99, onCancel: {},
                    onBuy: {})
            }
        case "home-decorate":
            HakuHomeView(
                snapshot: Self.home(), onSwitch: { _ in }, onShop: nil, onWardrobe: nil, onSave: { _ in }, onExit: {})
        default:
            ShopView(growth: growth, wardrobe: $wardrobe, persona: ScreenshotMode.persona)
        }
    }

    private static var stripedRug: String {
        ScreenshotMode.persona == .kuro ? "kuro.room.rug.stripe" : "room.rug.stripe"
    }

    // A room of its own, in memory, with the striped rug bought, so the panel shows the rug's styles.
    private static func home() -> HomeSnapshot {
        let growth = growth()
        if let rug = ShopItem.item(stripedRug) { try? growth.buy(rug) }
        let suite = "screenshot-home"
        UserDefaults().removePersistentDomain(forName: suite)
        return HomeSnapshot.make(
            persona: ScreenshotMode.persona, mode: .chill, today: [], ledger: growth.ledger, energy: EnergyLog(),
            bedtime: .off, defaults: UserDefaults(suiteName: suite) ?? .standard)
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
