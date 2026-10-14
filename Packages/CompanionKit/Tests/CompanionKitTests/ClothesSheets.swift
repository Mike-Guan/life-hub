#if os(macOS)
import Foundation
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// Preview only (preview/haku-clothes): HAKU's pop clothes worn in their modes, on the watch, as icons, from the
// back and under the warmup headband. Never merged.
extension FrameSheets {
    static let clothes = ShopItem.catalog(for: .haku).filter { $0.mode != nil }

    @Test func hakuClothes() throws {
        let rows = Self.clothes.map { item in
            Row(label: "\(item.title) (\(item.mode!.rawValue))", start: Self.base) {
                AnyView(CompanionView(mode: item.mode, wardrobe: Wardrobe(clothes: [item.mode!: item.id])))
            }
        }
        try write("clothes-1-phone", rows, frames: 4, step: 0.6)
    }

    @Test func hakuClothesWatch() throws {
        let rows = Self.clothes.map { item in
            Row(label: "watch · \(item.title)", start: Self.base) {
                AnyView(
                    CompanionView(mode: item.mode, wardrobe: Wardrobe(clothes: [item.mode!: item.id]), style: .watch))
            }
        }
        try write("clothes-2-watch", rows, size: CGSize(width: 198, height: 242), frames: 1)
    }

    @Test func hakuClothesIcons() throws {
        let rows = Self.clothes.map { item in
            Row(label: "icon · \(item.title)", start: Self.base) {
                AnyView(
                    WardrobeItemIcon(item: item)
                        .padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Toy.pink))
            }
        }
        try write("clothes-3-icons", rows, size: CGSize(width: 120, height: 120), frames: 1)
    }

    @Test func hakuClothesBacks() throws {
        let rows = Self.clothes.map { item in
            Row(label: "背面 · \(item.title)", start: Self.base) {
                var away = RunnerPose().wearing(Outfit(Wardrobe(clothes: [item.mode!: item.id])))
                away.turnedAway = true
                return AnyView(StillHaku(mode: item.mode!, pose: away))
            }
        }
        try write("clothes-5-backs", rows, frames: 1)
    }

    @Test func hakuClothesEdges() throws {
        let varsity = Outfit(Wardrobe(clothes: [.chill: "haku.set.chill.varsity"]))
        let raincoat = Outfit(Wardrobe(clothes: [.work: "haku.set.work.raincoat"]))
        var away = RunnerPose().wearing(raincoat)
        away.turnedAway = true
        let rows = [
            Row(label: "校队 + 拳击热身头带", start: Self.base) {
                AnyView(StillHaku(mode: .chill, pose: RunnerPose(need: .boxingWarmup).wearing(varsity)))
            },
            Row(label: "雨衣 背面", start: Self.base) { AnyView(StillHaku(mode: .work, pose: away)) },
        ]
        try write("clothes-4-edges", rows, frames: 1)
    }
}

/// HAKU in one fixed pose on the mode's colour.
private struct StillHaku: View {
    let mode: Mode
    let pose: RunnerPose

    var body: some View {
        RunnerFigure(mode: mode, pose: pose)
            .aspectRatio(RunnerArt.bounds.width / RunnerArt.bounds.height, contentMode: .fit)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(mode.color)
    }
}
#endif
