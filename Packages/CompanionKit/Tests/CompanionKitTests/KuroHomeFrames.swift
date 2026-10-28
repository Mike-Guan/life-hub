#if os(macOS)
import HubCore
import SpriteKit
import SwiftUI
import Testing

@testable import CompanionKit

// 第二个预设角色 in the home (Mike 2026-10-17): the same room and spots as HAKU, drawn with her own figure,
// for the UI review.
extension FrameSheets {
    @Test func kuroHome() throws {
        let states: [(String, Bool, IdentityKind, EnergyLevel?, Double, (HomeModel) -> Void)] = [
            ("夜 · 站着", true, .tennis, nil, 1.3, { _ in }),
            ("白天 · 站着", false, .tennis, nil, 1.3, { _ in }),
            ("累了 · 站着", false, .tennis, .low, 1.3, { _ in }),
            ("上班 · 书桌", true, .tennis, nil, 1.3, { $0.switchMode(.work) }),
            ("下班 · 沙发", true, .tennis, nil, 1.3, { $0.switchMode(.chill) }),
            ("网球日", false, .tennis, nil, 0.3, { $0.switchMode(.boxing) }),
            ("拳击卡 · 护脸", false, .boxing, nil, 0.1, { $0.switchMode(.boxing) }),
            ("拳击卡 · 出拳中", false, .boxing, nil, 0.33, { $0.switchMode(.boxing) }),
            ("拳击卡 · 出拳", false, .boxing, nil, 0.4, { $0.switchMode(.boxing) }),
            ("备课 · 书桌", true, .tennis, nil, 1.3, { $0.switchMode(.money) }),
            ("衣柜前", false, .tennis, nil, 1.3, { $0.tap(.wardrobe) }),
            ("床上 · 白天", false, .tennis, nil, 1.3, { $0.tap(.bed) }),
            ("床上 · 夜 抱平板", true, .tennis, nil, 1.3, { $0.tap(.bed) }),
            ("床上 · 夜 点头睡着", true, .tennis, nil, 8.5, { $0.tap(.bed) }),
        ]
        var cells: [(String, CGImage)] = []
        for (label, night, card, energy, t, setup) in states {
            let model = HomeModel(kuroAtNight: night, card: card, energy: energy)
            let scene = HomeScene(model: model)
            #expect(scene.haku is KuroHomeNode)
            setup(model)
            scene.sync(animated: false)
            scene.settle()
            scene.pose(at: t)
            cells.append((label, try #require(Self.closeUp(scene))))
        }
        let model = HomeModel(kuroAtNight: false, card: .tennis)
        let scene = HomeScene(model: model)
        model.switchMode(.work)
        scene.sync(animated: false)
        scene.step(1.0)
        cells.append(("走路中", try #require(Self.closeUp(scene))))
        #expect(scene.beginDrag(at: CGPoint(x: scene.haku.position.x, y: scene.haku.position.y + 40)))
        scene.drag(to: CGPoint(x: 320, y: 330))
        scene.pose(at: 2.2)
        cells.append(("被拎起来", try #require(Self.closeUp(scene))))

        let sheet = VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "家 · 第二个预设角色（接进家页面，每格 120×120 pt）")
                .font(.system(size: 16, weight: .bold))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(240)), count: 4), spacing: 10) {
                ForEach(cells.indices, id: \.self) { i in
                    VStack(spacing: 2) {
                        Image(decorative: cells[i].1, scale: 1).resizable().frame(width: 240, height: 240)
                        Text(verbatim: cells[i].0).font(.system(size: 12, weight: .bold))
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        try save(sheet, as: "kuro-home-1-close", scale: 1)
    }

    // 商店与家 同步方案 v0 §3: in the home she wears the tops and sets she bought, front and back, for the UI review.
    @Test func kuroHomeClothes() throws {
        let clothes: [(KuroItem, String)] = [
            (.workBlouse, "蝴蝶结衬衫"), (.chillCardigan, "毛绒开衫"), (.workVest, "针织马甲"), (.sideSmock, "格子罩衫"),
            (.chillHoodie, "猫耳卫衣"), (.sideDenim, "牛仔外套"), (.picnic, "野餐"), (.rain, "雨天"),
        ]
        var cells: [(String, CGImage)] = []
        for (item, name) in clothes {
            for back in [false, true] {
                let mode: Mode = item.look == .work ? .work : item.look == .desk ? .money : .chill
                let model = HomeModel(kuroAtNight: false, card: .tennis, wearing: [mode: item.rawValue])
                let scene = HomeScene(model: model)
                model.switchMode(mode)
                if back { model.tap(.wardrobe) }
                scene.sync(animated: false)
                scene.settle()
                scene.pose(at: 1.3)
                cells.append(("\(name) · \(back ? "背面" : "正面")", try #require(Self.closeUp(scene))))
            }
        }
        let sheet = VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "家 · 第二个预设角色穿买的衣服（正面 / 背面，每格 120×120 pt）")
                .font(.system(size: 16, weight: .bold))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(240)), count: 4), spacing: 10) {
                ForEach(cells.indices, id: \.self) { i in
                    VStack(spacing: 2) {
                        Image(decorative: cells[i].1, scale: 1).resizable().frame(width: 240, height: 240)
                        Text(verbatim: cells[i].0).font(.system(size: 12, weight: .bold))
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        try save(sheet, as: "kuro-home-clothes", scale: 1)
    }

    /// A 120 pt square of the scene around her, two pixels per point.
    private static func closeUp(_ scene: CompanionKit.HomeScene) -> CGImage? {
        guard let image = composite(scene, scale: 2) else { return nil }
        let p = scene.haku.position
        let rect = CGRect(x: (p.x - 60) * 2, y: (scene.size.height - p.y - 90) * 2, width: 240, height: 240)
        return image.cropping(to: rect)
    }
}

extension HomeModel {
    /// Her room before any mode, as the app would send it.
    fileprivate convenience init(
        kuroAtNight night: Bool, card: IdentityKind, energy: EnergyLevel? = nil, wearing: [Mode: String] = [:]
    ) {
        var snapshot = HomeSnapshot.preview()
        snapshot.persona = .kuro
        snapshot.wardrobe = Wardrobe(clothes: wearing)
        // What she wears follows the snapshot's mode, so the clothes' mode is the snapshot's too.
        if let mode = wearing.keys.first { snapshot.mode = mode }
        snapshot.cards = ModeCards(identity: card)
        snapshot.energy = energy
        self.init(snapshot: snapshot, night: night, now: Self.start)
    }
}
#endif
