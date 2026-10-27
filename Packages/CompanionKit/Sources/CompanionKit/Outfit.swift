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
    /// The print drawn over the headband, such as checks, or `nil` for a plain band.
    var headbandPrint: RunnerPart?
    /// The print on the mask, or `nil` for the plain mask.
    var mask: MaskPrint?
    /// The room item next to HAKU at home, or `nil` for none.
    var room: RunnerPart?
    /// Colours swapped in the identity card's prop, by part, such as the racket's frame; empty for its own colours.
    var props: [RunnerPart: [Color: Color]] = [:]
    /// A sneaky peace sign in every celebration and unboxing.
    var peaceSign = false
    /// The parts of the top or full set worn in each mode, in place of the jacket.
    var clothes: [Mode: Set<RunnerPart>] = [:]
    /// The base colour of the top or full set worn in each mode, for the back of the jacket.
    var clothesBack: [Mode: Color] = [:]

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
            case "haku.weekly.headband.orange": RunnerPalette.catOrange
            case "haku.weekly.headband.mint": RunnerPalette.mint
            case "haku.headband.check": RunnerPalette.cream
            case "haku.headband.flame": RunnerPalette.jacket
            default: nil
            }
        // 商店扩充 v1 §3.
        headbandPrint =
            switch worn[.headband] {
            case "haku.headband.check": .headbandCheck
            case "haku.headband.flame": .headbandFlame
            default: nil
            }
        props = worn[.gloves].flatMap { Self.propColors[$0] } ?? [:]
        mask =
            switch worn[.mask] {
            case "mask.stripes": .stripes
            case "haku.weekly.mask.dots": .dots
            case "haku.weekly.mask.bolt": .bolt
            case "haku.mask.smile": .smile
            default: nil
            }
        room =
            switch worn[.room] {
            case "room.plant": .roomPlant
            case "room.bag": .roomBag
            case "haku.weekly.room.cactus": .roomCactus
            case "haku.weekly.room.speaker": .roomSpeaker
            default: nil
            }
        peaceSign = worn[.celebration] == "celebrate.up"
        clothes = wardrobe.clothes.compactMapValues { Self.clothesParts[$0] }
        clothesBack = wardrobe.clothes.compactMapValues { Self.clothesBackColors[$0] }
    }

    // 商店完整目录 v0 §1.2 and 商店扩充 v1 §4: each card's prop in a bought colour, and in gold on the card's 10th
    // win. The props share the gloves slot. Ids not yet in the catalog (dance, ski) are the ones handed to engineering.
    static let propColors: [String: [RunnerPart: [Color: Color]]] = [
        "haku.racket.tennis.mint": [.tennisRacket: [RunnerPalette.catOrange: RunnerPalette.mint]],
        "haku.racket.tennis.gold": [.tennisRacket: [RunnerPalette.catOrange: RunnerPalette.gold]],
        "haku.dumbbell.gym.orange": [
            .handWeight: [RunnerPalette.mask: RunnerPalette.catOrange, RunnerPalette.maskLine: Color(hex: 0xC9721F)]
        ],
        "haku.dumbbell.gym.gold": [
            .handWeight: [RunnerPalette.mask: RunnerPalette.gold, RunnerPalette.maskLine: Color(hex: 0xB8901A)]
        ],
        // The default cover is already navy, so the bought one is wine red (proposed to PM 10/27).
        "haku.book.study.navy": [.book: [RunnerPalette.hood: Color(hex: 0x8E2A44)]],
        "haku.sketch.art.yellow": [.sketchbook: [RunnerPalette.white: RunnerPalette.catYellow]],
        // A deeper gold than the pencil's own yellow, so the keepsake reads as gold.
        "haku.pencil.art.gold": [.pencil: [RunnerPalette.catYellow: Color(hex: 0xE8A317)]],
        "haku.wristband.dance.pink": [.wristbandHand: [RunnerPalette.catOrange: RunnerPalette.neonPink]],
        "haku.wristband.dance.gold": [.wristbandHand: [RunnerPalette.catOrange: RunnerPalette.gold]],
        "haku.goggles.ski.cyan": [.skiGoggles: [RunnerPalette.catOrange: RunnerPalette.neonCyan]],
        "haku.goggles.ski.gold": [.skiGoggles: [RunnerPalette.catOrange: RunnerPalette.gold]],
    ]

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

    // UI 审核 2026-10-14: from the back each top shows as a plain jacket in its base colour, like the second character.
    static let clothesBackColors: [String: Color] = [
        "haku.top.work.blazer": RunnerPalette.hood,
        "haku.top.work.cardigan": RunnerPalette.cream,
        "haku.top.chill.aloha": RunnerPalette.catOrange,
        "haku.top.chill.flame": RunnerPalette.bubblegum,
        "haku.top.side.sukajan": RunnerPalette.hood,
        "haku.top.side.arcade": RunnerPalette.cream,
        "haku.set.chill.varsity": RunnerPalette.varsityRed,
        "haku.set.work.raincoat": RunnerPalette.lilac,
    ]
}

/// A print on HAKU's mask.
enum MaskPrint: CaseIterable, Sendable {
    /// Pink stripes instead of the panel lines.
    case stripes
    /// White dots on both sides.
    case dots
    /// A yellow lightning bolt sticker.
    case bolt
    /// A yellow smiley sticker.
    case smile

    /// The print on the raised mask.
    var up: RunnerPart {
        switch self {
        case .stripes: .maskStripes
        case .dots: .maskDots
        case .bolt: .maskBolt
        case .smile: .maskSmile
        }
    }

    /// The print on the mask pulled down to the chin.
    var down: RunnerPart {
        switch self {
        case .stripes: .maskStripesDown
        case .dots: .maskDotsDown
        case .bolt: .maskBoltDown
        case .smile: .maskSmileDown
        }
    }
}

extension RunnerPalette {
    // Only the Sunday headband uses it, at runtime, so it is not in the SVG.
    /// Mint, for the mint headband.
    static let mint = Color(hex: 0x7EEBC6)
}
