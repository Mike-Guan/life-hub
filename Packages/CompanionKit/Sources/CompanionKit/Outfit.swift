import HubCore
import SwiftUI

// CompanionKit only maps wardrobe ids to looks; HubCore owns the catalog. Ids this build
// doesn't know, such as items from a newer build, leave the default look.
/// What HAKU wears from the wardrobe, as changes to its default look.
struct Outfit: Equatable, Sendable {
    /// Replaces the boxing red of the gloves, or `nil` for red.
    var gloves: Color?
    /// Replaces the boxing red of the headband, or `nil` for red.
    var headband: Color?
    /// Pink stripes on the mask instead of its panel lines.
    var stripedMask = false
    /// The room item next to HAKU at home, or `nil` for none.
    var room: RunnerPart?
    /// A sneaky peace sign in every celebration and unboxing.
    var peaceSign = false
    /// The parts of the top or full set worn in each mode, in place of the jacket.
    var clothes: [Mode: Set<RunnerPart>] = [:]

    /// The default look.
    init() {}

    /// The look for what `wardrobe` has equipped.
    init(_ wardrobe: Wardrobe) {
        let worn = wardrobe.equipped
        gloves =
            switch worn[.gloves] {
            case "gloves.pink": RunnerPalette.neonPink
            case "gloves.gold": RunnerPalette.gold
            default: nil
            }
        headband =
            switch worn[.headband] {
            case "headband.cyan": RunnerPalette.neonCyan
            case "keepsake.headband.runner": RunnerPalette.white
            default: nil
            }
        stripedMask = worn[.mask] == "mask.stripes"
        room =
            switch worn[.room] {
            case "room.plant": .roomPlant
            case "room.bag": .roomBag
            default: nil
            }
        peaceSign = worn[.celebration] == "celebrate.up"
        clothes = wardrobe.clothes.compactMapValues { Self.clothesParts[$0] }
    }

    // 商店衣服 pop (Mike 2026-10-14). The second character's clothes are not drawn yet.
    static let clothesParts: [String: Set<RunnerPart>] = [
        "haku.top.work.blazer": [.topWorkIvy],
        "haku.top.work.cardigan": [.topWorkPixel],
        "haku.top.chill.aloha": [.topChillAloha],
        "haku.top.chill.flame": [.topChillFlame, .hoodieStringsCyan],
        "haku.top.side.sukajan": [.topSideSouvenir],
        "haku.top.side.arcade": [.topSideArcade, .sideCassette],
        "haku.set.chill.varsity": [.setVarsityTop, .setVarsityCap],
        "haku.set.work.raincoat": [.setKawaiiHood, .setKawaiiTop, .setDuckCharm],
    ]
}
