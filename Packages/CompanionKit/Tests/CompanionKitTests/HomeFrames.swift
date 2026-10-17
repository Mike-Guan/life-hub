#if os(macOS)
import HubCore
import SpriteKit
import SwiftUI
import Testing

@testable import CompanionKit

// Issue #485: stills of the home prototype for the review. SpriteKit needs a GPU to draw, so each sprite's
// texture is composited here with Core Graphics, in the scene's own order.
extension FrameSheets {
    @Test func hakuHome() throws {
        let states: [(String, Bool, (HomeModel) -> Void)] = [
            ("夜 · 站着", true, { _ in }),
            ("白天 · 站着", false, { _ in }),
            ("上班 · 书桌", true, { $0.switchMode(.work) }),
            ("下班 · 沙发", true, { $0.switchMode(.chill) }),
            ("拳击日 · 没沙袋", false, { $0.switchMode(.boxing) }),
            (
                "拳击日 · 沙袋", true,
                {
                    $0.buy(.item(.bag))
                    $0.switchMode(.boxing)
                }
            ),
            ("副业 · 书桌", true, { $0.switchMode(.money) }),
            (
                "预览摆满 · 拳击日", false,
                {
                    $0.togglePreviewItems()
                    $0.switchMode(.boxing)
                }
            ),
            (
                "预览摆满 · 窗边", true,
                {
                    $0.togglePreviewItems()
                    $0.tap(.window)
                }
            ),
            ("床上休息", true, { $0.tap(.bed) }),
            ("衣柜前", false, { $0.tap(.wardrobe) }),
            (
                "买齐 + 换色 + 西装", false,
                {
                    $0.buy(.item(.plant))
                    $0.buy(.item(.cactus))
                    $0.buy(.item(.speaker))
                    $0.wear(.blazer)
                    $0.paint(.sofa, 2)
                    $0.paint(.rug, 3)
                    $0.paint(.walls, 1)
                    $0.tap(.sofa)
                }
            ),
        ]
        var cells: [(String, CGImage)] = []
        for (label, night, setup) in states {
            let model = HomeModel(night: night, cans: 120)
            let scene = HomeScene(model: model)
            setup(model)
            scene.sync(animated: false)
            scene.settle()
            scene.pose(at: 1.3)
            let image = try #require(Self.composite(scene, scale: 2))
            cells.append((label, image))
        }
        // Fitness day with the bench: the bar up at lockout, then down on the chest.
        for (label, t) in [("健身日 · 卧推 推起", 1.3), ("健身日 · 卧推 放下", 0.05)] {
            let model = HomeModel(night: false, cans: 120, card: .fitness)
            let scene = HomeScene(model: model)
            model.buy(.item(.bench))
            model.switchMode(.boxing)
            scene.sync(animated: false)
            scene.settle()
            scene.pose(at: t)
            cells.append((label, try #require(Self.composite(scene, scale: 2))))
        }
        // Mid-walk and carried, from the first room.
        let model = HomeModel(night: true, cans: 120)
        let scene = HomeScene(model: model)
        model.switchMode(.work)
        scene.sync(animated: false)
        scene.step(1.0)
        let walking = try #require(Self.composite(scene, scale: 2))
        cells.append(("走路中", walking))
        #expect(scene.beginDrag(at: CGPoint(x: scene.haku.position.x, y: scene.haku.position.y + 40)))
        scene.drag(to: CGPoint(x: 320, y: 330))
        scene.pose(at: 2.2)
        let carried = try #require(Self.composite(scene, scale: 2))
        cells.append(("被拎起来", carried))
        // Dropped on the bed: he lies down on the pillow, not where the finger let go.
        let bed = HomeGrid.scene(HomeGrid.plan(8.2, 6.2, 0.9))
        scene.drag(to: CGPoint(x: bed.x, y: bed.y + 64))
        scene.endDrag(at: CGPoint(x: bed.x, y: bed.y + 64))
        scene.pose(at: 2.6)
        let dropped = try #require(Self.composite(scene, scale: 2))
        cells.append(("丢到床上", dropped))
        // Off the bed and over to the desk, the short way round.
        model.switchMode(.work)
        scene.sync(animated: false)
        scene.step(1.4)
        let crossing = try #require(Self.composite(scene, scale: 2))
        cells.append(("床 → 书桌 路上", crossing))

        let sheet = VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: "家（原型）· Issue #485").font(.system(size: 20, weight: .bold))
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
        try save(sheet, as: "home-1-states", scale: 1)
        try save(Image(decorative: cells[0].1, scale: 1).background(Toy.paper), as: "home-2-night-big", scale: 1)
    }

    // The shop's room items: the small icon, and the 260 pt preview of the item where it stands with HAKU beside it.
    @Test func hakuHomeShopItems() throws {
        let side: CGFloat = 260
        var cells: [(String, CGImage, HomeItem)] = []
        for id in [
            "room.plant", "room.bag", "haku.weekly.room.cactus", "haku.weekly.room.speaker", "room.bench",
            "room.snowboard",
        ] {
            let item = try #require(HomeItem(shopID: id))
            let model = HomeModel(night: false, cans: 999)
            let scene = HomeScene(model: model)
            _ = model.buy(.item(item))
            model.standBeside(item)
            scene.sync(animated: false)
            scene.settle()
            scene.pose(at: 1.3)
            cells.append((id, try #require(Self.composite(scene, scale: 3)), item))
        }
        let canvas = HomeGrid.canvas
        let sheet = VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: "商店 · 房间物品：小图标 + 260 pt 预览").font(.system(size: 20, weight: .bold))
            LazyVGrid(columns: [GridItem(.fixed(side + 90)), GridItem(.fixed(side + 90))], spacing: 16) {
                ForEach(cells.indices, id: \.self) { i in
                    let (id, image, item) = cells[i]
                    let crop = HomeItemPreview.crop(item, haku: HomeModel.previewSpot(item))
                    let ring = HomeItemPreview.ring(item)
                    let k = side / crop.width
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 4) {
                            HomeItemIcon(itemID: id).frame(width: 72, height: 72)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Toy.card))
                            Text(verbatim: id).font(.system(size: 9)).frame(width: 80)
                        }
                        ZStack(alignment: .topLeading) {
                            Image(decorative: image, scale: 3).resizable()
                                .frame(width: canvas.width * k, height: canvas.height * k)
                            Ellipse().stroke(Toy.pink, style: StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
                                .frame(width: ring.width * k, height: ring.height * k)
                                .offset(x: (ring.minX - canvas.minX) * k, y: (ring.minY - canvas.minY) * k)
                        }
                        .offset(x: -(crop.minX - canvas.minX) * k, y: -(crop.minY - canvas.minY) * k)
                        .frame(width: side, height: side, alignment: .topLeading)
                        .clipped()
                        .background(Toy.paper)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        try save(sheet, as: "home-4-shop-items", scale: 2)
    }

    /// Draws the scene's sprites back to front with Core Graphics.
    static func composite(_ scene: SKScene, scale: CGFloat) -> CGImage? {
        scene.still(scale: scale)
    }
}
#endif
