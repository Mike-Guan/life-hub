#if os(macOS)
import HubCore
import SpriteKit
import SwiftUI
import Testing

@testable import CompanionKit

// 商店与家 同步方案 v0, M4: every drawn top in the room, front, back, at the desk and on the sofa, then the first
// week's accessories, for the UI review.
extension FrameSheets {
    @Test func hakuHomeClothes() throws {
        let columns: [(String, Bool, (HomeModel) -> Void)] = [
            ("站着", false, { _ in }),
            ("背面 · 衣柜前", false, { $0.tap(.wardrobe) }),
            ("书桌", true, { $0.switchMode(.work) }),
            ("沙发", true, { $0.switchMode(.chill) }),
        ]
        var rows: [(String, [CGImage])] = []
        for outfit in HomeOutfit.allCases {
            var cells: [CGImage] = []
            for (_, night, setup) in columns {
                let model = HomeModel(night: night)
                let scene = HomeScene(model: model)
                model.wearEverywhere(outfit)
                setup(model)
                scene.sync(animated: false)
                scene.settle()
                scene.pose(at: 1.3)
                cells.append(try #require(Self.hakuCloseUp(scene)))
            }
            rows.append((outfit.name, cells))
        }
        var extras: [(String, CGImage)] = []
        let looks: [(String, [Slot: String], HomeOutfit, Mode?, Double)] = [
            ("青色头带 + 粉拳套 · 护脸", [.headband: "headband.cyan", .gloves: "gloves.pink"], .jacket, .boxing, 0.1),
            ("青色头带 + 粉拳套 · 出拳", [.headband: "headband.cyan", .gloves: "gloves.pink"], .jacket, .boxing, 0.4),
            ("条纹面罩（下巴上）", [.mask: "mask.stripes"], .jacket, nil, 1.3),
            ("条纹面罩 · 书桌", [.mask: "mask.stripes"], .jacket, .work, 1.3),
            ("校队夹克 · 拳击日（帽子让给头带）", [:], .varsity, .boxing, 0.1),
        ]
        for (label, equipped, outfit, mode, t) in looks {
            let model = HomeModel(night: false)
            let scene = HomeScene(model: model)
            model.wearEverywhere(outfit, equipped: equipped)
            if let mode { model.switchMode(mode) }
            scene.sync(animated: false)
            scene.settle()
            scene.pose(at: t)
            extras.append((label, try #require(Self.hakuCloseUp(scene))))
        }
        let sheet = VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "家 · HAKU 衣服房间版（每格 120×120 pt）").font(.system(size: 16, weight: .bold))
            HStack(spacing: 10) {
                Text(verbatim: "").frame(width: 110)
                ForEach(columns.indices, id: \.self) { i in
                    Text(verbatim: columns[i].0).font(.system(size: 12, weight: .bold)).frame(width: 240)
                }
            }
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 10) {
                    Text(verbatim: rows[r].0).font(.system(size: 12, weight: .bold)).frame(
                        width: 110, alignment: .leading)
                    ForEach(rows[r].1.indices, id: \.self) { c in
                        Image(decorative: rows[r].1[c], scale: 1).resizable().frame(width: 240, height: 240)
                    }
                }
            }
            Text(verbatim: "第 1 周配饰").font(.system(size: 14, weight: .bold))
            HStack(alignment: .top, spacing: 10) {
                ForEach(extras.indices, id: \.self) { i in
                    VStack(spacing: 2) {
                        Image(decorative: extras[i].1, scale: 1).resizable().frame(width: 240, height: 240)
                        Text(verbatim: extras[i].0).font(.system(size: 11, weight: .bold)).frame(width: 240)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        try save(sheet, as: "home-10-clothes", scale: 1)
    }

    /// A 120 pt square of the scene around HAKU, two pixels per point.
    private static func hakuCloseUp(_ scene: CompanionKit.HomeScene) -> CGImage? {
        guard let image = composite(scene, scale: 2) else { return nil }
        let p = scene.haku.position
        let rect = CGRect(x: (p.x - 60) * 2, y: (scene.size.height - p.y - 90) * 2, width: 240, height: 240)
        return image.cropping(to: rect)
    }
}

extension HomeModel {
    /// Hands the model a snapshot in which HAKU wears `outfit` in every mode, with `equipped` on.
    fileprivate func wearEverywhere(_ outfit: HomeOutfit, equipped: [Slot: String] = [:]) {
        var next = snapshot
        for mode in Mode.allCases {
            next.wardrobe.clothes[mode] = outfit.shopID
        }
        next.wardrobe.equipped.merge(equipped) { $1 }
        next.owned.formUnion(equipped.values)
        if let id = outfit.shopID { next.owned.insert(id) }
        apply(next)
    }
}
#endif
