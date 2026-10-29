#if os(macOS)
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// 商店扩充 v1 §4 and 商店完整目录 v0 §1.2: each card's prop in its bought colour and in gold, beside its own colours.
extension FrameSheets {
    @Test func hakuCardPropColours() throws {
        let rows: [(IdentityKind, [String])] = [
            (.tennis, ["haku.racket.tennis.mint", "haku.racket.tennis.gold"]),
            (.fitness, ["haku.dumbbell.gym.orange", "haku.dumbbell.gym.gold"]),
            (.study, ["haku.book.study.navy", "haku.bookmark.study.gold"]),
            (.art, ["haku.sketch.art.yellow", "haku.pencil.art.gold"]),
            (.dance, ["haku.wristband.dance.pink", "haku.wristband.dance.gold"]),
            (.music, ["haku.pick.music.neon", "haku.pick.music.gold"]),
            (.ski, ["haku.goggles.ski.cyan", "haku.goggles.ski.gold"]),
        ]
        let sheet = VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: "HAKU 卡的道具配色：原色 · 买的颜色 · 金（第 10 次）").font(.system(size: 18, weight: .bold))
            ForEach(rows.indices, id: \.self) { i in
                let (card, ids) = rows[i]
                HStack(alignment: .bottom, spacing: 14) {
                    Text(verbatim: card.rawValue).font(.system(size: 13, weight: .bold)).frame(width: 60)
                    ForEach([""] + ids, id: \.self) { id in
                        let wardrobe = id.isEmpty ? Wardrobe() : Wardrobe(equipped: [.gloves: id])
                        VStack(spacing: 4) {
                            HStack(alignment: .bottom, spacing: 4) {
                                CompanionPortrait(
                                    mode: .boxing, card: card, date: Self.base, wardrobe: wardrobe, idles: false
                                )
                                .frame(width: 150, height: 150)
                                if !id.isEmpty {
                                    PropIcon(outfit: Outfit(wardrobe), id: id)
                                        .frame(width: 56, height: 56)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Slot.gloves.tileColor))
                                }
                            }
                            Text(verbatim: id.isEmpty ? "原色" : id).font(.system(size: 10))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        try save(sheet, as: "card-prop-colours", scale: 2)
    }

    // 商店扩充 v1 §3: the checked and the flame headband in boxing, the smiley mask raised at work and at the chin.
    @Test func hakuShopAccessories() throws {
        let looks: [(String, Mode, Slot, String)] = [
            ("格纹头带", .boxing, .headband, "haku.headband.check"),
            ("火焰头带", .boxing, .headband, "haku.headband.flame"),
            ("笑脸面罩 · 上班", .work, .mask, "haku.mask.smile"),
            ("笑脸面罩 · 下班", .chill, .mask, "haku.mask.smile"),
        ]
        let sheet = VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: "HAKU 配饰 3 件（全身 + 头部放大 + 商店小图标）").font(.system(size: 18, weight: .bold))
            HStack(alignment: .top, spacing: 16) {
                ForEach(looks.indices, id: \.self) { i in
                    let (label, mode, slot, id) = looks[i]
                    let wardrobe = Wardrobe(equipped: [slot: id])
                    VStack(spacing: 6) {
                        CompanionPortrait(mode: mode, date: Self.base, wardrobe: wardrobe, idles: false)
                            .frame(width: 180, height: 180)
                        CompanionPortrait(
                            mode: mode, date: Self.base, wardrobe: wardrobe, idles: false, framing: .head
                        )
                        .frame(width: 120, height: 120)
                        AccessoryIcon(picture: ItemPicture(slot: slot, outfit: Outfit(wardrobe), itemID: id))
                            .frame(width: 56, height: 56)
                            .background(RoundedRectangle(cornerRadius: 10).fill(slot.tileColor))
                        Text(verbatim: label).font(.system(size: 12, weight: .bold))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        try save(sheet, as: "haku-accessories", scale: 2)
    }
}

/// An item icon's drawing, as `WardrobeItemIcon` draws it, for items not in the catalog yet.
private struct AccessoryIcon: View {
    let picture: ItemPicture

    var body: some View {
        Canvas { context, size in
            let crop = picture.crop
            let scale = min(size.width / crop.width, size.height / crop.height)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -crop.minX, y: -crop.minY)
            for part in picture.parts {
                RunnerDrawing.draw(part, in: context, red: picture.red, swaps: picture.swaps[part] ?? [:])
            }
        }
    }
}

/// The shop icon's drawing of a prop, as `WardrobeItemIcon` draws it, for items not in the catalog yet.
private struct PropIcon: View {
    let outfit: Outfit
    let id: String

    var body: some View {
        let picture = ItemPicture(slot: .gloves, outfit: outfit, itemID: id)
        Canvas { context, size in
            let crop = picture.crop
            let scale = min(size.width / crop.width, size.height / crop.height)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -crop.minX, y: -crop.minY)
            for part in picture.parts {
                RunnerDrawing.draw(part, in: context, swaps: picture.swaps[part] ?? [:])
            }
        }
    }
}
#endif
