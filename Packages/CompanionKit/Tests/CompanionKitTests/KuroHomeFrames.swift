#if os(macOS)
import HubCore
import SpriteKit
import SwiftUI
import Testing

@testable import CompanionKit

// 第二个预设角色 in the home (Mike 2026-10-17): the same room and spots as HAKU, drawn with her own rig, for the
// UI review. The scene still poses HAKU; he is hidden and she stands where he would, in the pose he would take.
extension FrameSheets {
    @Test func kuroHome() throws {
        let states: [(String, Bool, IdentityKind, EnergyLevel?, Double, (HomeModel) -> Void)] = [
            ("夜 · 站着", true, .tennis, nil, 1.3, { _ in }),
            ("白天 · 站着", false, .tennis, nil, 1.3, { _ in }),
            ("累了 · 站着", false, .tennis, .low, 1.3, { _ in }),
            ("上班 · 书桌", true, .tennis, nil, 1.3, { $0.switchMode(.work) }),
            ("下班 · 沙发", true, .tennis, nil, 1.3, { $0.switchMode(.chill) }),
            ("网球日 · 挥拍", false, .tennis, nil, 0.45, { $0.switchMode(.boxing) }),
            ("拳击卡 · 戴手套", false, .boxing, nil, 0.4, { $0.switchMode(.boxing) }),
            ("备课 · 书桌", true, .tennis, nil, 1.3, { $0.switchMode(.money) }),
            ("衣柜前", false, .tennis, nil, 1.3, { $0.tap(.wardrobe) }),
            ("床上 · 白天 盖被睡", false, .tennis, nil, 1.3, { $0.tap(.bed) }),
            ("床上 · 夜 抱平板", true, .tennis, nil, 1.3, { $0.tap(.bed) }),
            ("床上 · 夜 点头睡着", true, .tennis, nil, 8.5, { $0.tap(.bed) }),
        ]
        var cells: [(String, CGImage)] = []
        var close: [(String, CGImage)] = []
        for (label, night, card, energy, t, setup) in states {
            let model = HomeModel(night: night, card: card, energy: energy)
            let scene = HomeScene(model: model)
            setup(model)
            scene.sync(animated: false)
            scene.settle()
            scene.pose(at: t)
            cells.append((label, try #require(Self.kuro(in: scene, model, t: t))))
            close.append((label, try #require(Self.closeUp(scene, model, t: t))))
        }
        // Mid-walk and carried.
        let model = HomeModel(night: false, card: .tennis)
        let scene = HomeScene(model: model)
        model.switchMode(.work)
        scene.sync(animated: false)
        scene.step(1.0)
        cells.append(("走路中", try #require(Self.kuro(in: scene, model, t: 1.0))))
        #expect(scene.beginDrag(at: CGPoint(x: scene.haku.position.x, y: scene.haku.position.y + 40)))
        scene.drag(to: CGPoint(x: 320, y: 330))
        scene.pose(at: 2.2)
        cells.append(("被拎起来", try #require(Self.kuro(in: scene, model, t: 2.2, carried: true))))

        let sheet = VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: "家 · 第二个预设角色（预览 v1）").font(.system(size: 20, weight: .bold))
            LazyVGrid(columns: [GridItem(.fixed(330)), GridItem(.fixed(330)), GridItem(.fixed(330))], spacing: 14) {
                ForEach(cells.indices, id: \.self) { i in
                    VStack(spacing: 4) {
                        Image(decorative: cells[i].1, scale: 2)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 330)
                            .background(Toy.paper)
                        Text(verbatim: cells[i].0).font(.system(size: 13, weight: .bold))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        try save(sheet, as: "kuro-home-1-states", scale: 1)

        let closeSheet = VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "近看（每格 120×120 pt）").font(.system(size: 16, weight: .bold))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(240)), count: 4), spacing: 10) {
                ForEach(close.indices, id: \.self) { i in
                    VStack(spacing: 2) {
                        Image(decorative: close[i].1, scale: 1).resizable().frame(width: 240, height: 240)
                        Text(verbatim: close[i].0).font(.system(size: 12, weight: .bold))
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        try save(closeSheet, as: "kuro-home-3-close", scale: 1)

        // Big, to judge her proportions next to the furniture.
        let big = HomeModel(night: false, card: .tennis)
        let room = HomeScene(model: big)
        big.switchMode(.chill)
        room.sync(animated: false)
        room.settle()
        room.pose(at: 1.3)
        let image = try #require(Self.kuro(in: room, big, t: 1.3, scale: 3))
        try save(Image(decorative: image, scale: 1).background(Toy.paper), as: "kuro-home-2-sofa-big", scale: 1)
    }

    /// The scene with her in HAKU's place and pose.
    private static func kuro(
        in scene: CompanionKit.HomeScene, _ model: HomeModel, t: Double, carried: Bool = false, scale: CGFloat = 2
    ) -> CGImage? {
        let (pose, face) = kuroPose(scene, model, t: t, carried: carried)
        let kuro = KuroHomeNode()
        kuro.dress(KuroLook(mode: model.mode ?? .chill, card: model.card), worn: [])
        let right = scene.spotReached?.facesRight ?? true
        kuro.apply(
            pose, face: face, facingRight: right, gloves: model.mode == .boxing && model.card == .boxing, t: t)
        kuro.position = scene.haku.position
        kuro.zPosition = scene.haku.zPosition
        scene.haku.isHidden = true
        scene.addChild(kuro)
        defer {
            kuro.removeFromParent()
            scene.haku.isHidden = false
        }
        return composite(scene, scale: scale)
    }

    /// A 120 pt square around her, two pixels per point.
    private static func closeUp(_ scene: CompanionKit.HomeScene, _ model: HomeModel, t: Double) -> CGImage? {
        guard let image = kuro(in: scene, model, t: t, scale: 2) else { return nil }
        let p = scene.haku.position
        let x = (p.x - 60) * 2
        let y = (scene.size.height - p.y - 90) * 2
        return image.cropping(to: CGRect(x: x, y: y, width: 240, height: 240))
    }

    // The pose `HomeScene` gives HAKU for the same moment, without his one-offs.
    private static func kuroPose(_ scene: CompanionKit.HomeScene, _ model: HomeModel, t: Double, carried: Bool)
        -> (HakuPose, HakuFace)
    {
        if carried { return (.dangle, .yawn) }
        if scene.isWalking { return (.walk, .idle) }
        let tired = model.isLow
        guard let spot = scene.spotReached else { return (tired ? .tired : .stand, tired ? .tired : .idle) }
        switch spot {
        case .idle: return (tired ? .tired : .stand, tired ? .tired : .idle)
        case .work, .side: return (.back, .focus)
        case .sofa: return (.sit, tired ? .tired : .chill)
        case .rest:
            if model.isNight { return (.doze, HakuNode.dozeNod(t) < 0.5 ? .idle : .closed) }
            return (.lie, .closed)
        case .box, .shadowbox: return (.box, .box)
        default: return (spot.pose, .focus)
        }
    }
}
#endif
