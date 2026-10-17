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
                    $0.own(.bag)
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
                    $0.own(.plant)
                    $0.own(.cactus)
                    $0.own(.speaker)
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
            let model = HomeModel(night: night)
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
            let model = HomeModel(night: false, card: .fitness)
            let scene = HomeScene(model: model)
            model.own(.bench)
            model.switchMode(.boxing)
            scene.sync(animated: false)
            scene.settle()
            scene.pose(at: t)
            cells.append((label, try #require(Self.composite(scene, scale: 2))))
        }
        // Mid-walk and carried, from the first room.
        let model = HomeModel(night: true)
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

    // The room at iPhone SE width (343 pt), each tap target's area drawn over it with its size in points.
    @Test func hakuHomeTapsOnSE() throws {
        let width: CGFloat = 343
        let s = width / HomeGrid.canvas.width
        let side = HomeGrid.minTap / s
        let model = HomeModel(night: false, card: .fitness)
        let scene = HomeScene(model: model)
        model.own(.bag)
        model.own(.bench)
        scene.sync(animated: false)
        scene.settle()
        scene.pose(at: 1.3)
        let image = try #require(Self.composite(scene, scale: 3))
        let height = HomeGrid.canvas.height * s
        func view(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * s, y: height - p.y * s) }
        var boxes: [(String, CGRect)] = []
        for hotspot in HomeHotspot.allCases {
            let outlines = scene.tapTargets().filter { $0.hotspot == hotspot }.map(\.outline)
            guard !outlines.isEmpty else { continue }
            let box = outlines.map { HomeScene.grown($0, to: side) }.reduce(CGRect.null) { $0.union($1) }
            let a = view(CGPoint(x: box.minX, y: box.maxY))
            boxes.append((hotspot.rawValue, CGRect(x: a.x, y: a.y, width: box.width * s, height: box.height * s)))
        }
        let haku = scene.haku.calculateAccumulatedFrame()
        let chips = HomeChip.all.map { chip in
            let p = HomeGrid.plan(chip.at)
            return (chip.title, CGPoint(x: (p.x - HomeGrid.canvas.minX) * s, y: (p.y - HomeGrid.canvas.minY) * s))
        }
        let room = ZStack(alignment: .topLeading) {
            Image(decorative: image, scale: 3).resizable().frame(width: width, height: height)
            ForEach(boxes.indices, id: \.self) { i in
                let (name, r) = boxes[i]
                Rectangle().stroke(Color.red, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .frame(width: r.width, height: r.height)
                    .overlay(alignment: .topLeading) {
                        Text(verbatim: "\(name) \(Int(r.width))×\(Int(r.height))")
                            .font(.system(size: 7, weight: .bold)).foregroundStyle(.red)
                            .background(Color.white.opacity(0.7))
                    }
                    .offset(x: r.minX, y: r.minY)
            }
            ForEach(chips.indices, id: \.self) { i in
                Rectangle().stroke(Color.blue, lineWidth: 1)
                    .frame(width: HomeGrid.minTap, height: HomeGrid.minTap)
                    .offset(x: chips[i].1.x - HomeGrid.minTap / 2, y: chips[i].1.y - HomeGrid.minTap / 2)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .background(Toy.paper)
        let sheet = VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "家 · iPhone SE（343 pt 宽）点按热区").font(.system(size: 15, weight: .bold))
            room
            Text(
                verbatim:
                    "HAKU 画面 \(Int(haku.width * s))×\(Int(haku.height * s)) pt。红框 = 场景热区（不足 44 pt 的向四周补齐），蓝框 = 标签按钮 44×44 pt。"
            )
            .font(.system(size: 10)).frame(width: width, alignment: .leading)
        }
        .padding(12)
        .background(Color.white)
        try save(sheet, as: "home-3-se-taps", scale: 3)
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
            let model = HomeModel(snapshot: .preview(owning: [id]), night: false)
            let scene = HomeScene(model: model)
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
        let width = Int(scene.size.width * scale)
        let height = Int(scene.size.height * scale)
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.scaleBy(x: scale, y: scale)
        var sprites: [(z: CGFloat, order: Int, node: SKSpriteNode)] = []
        var order = 0
        func walk(_ node: SKNode, z: CGFloat) {
            guard !node.isHidden else { return }
            let depth = z + node.zPosition
            if let sprite = node as? SKSpriteNode, sprite.texture != nil {
                sprites.append((depth, order, sprite))
                order += 1
            }
            for child in node.children { walk(child, z: depth) }
        }
        walk(scene, z: 0)
        for (_, _, sprite) in sprites.sorted(by: { ($0.z, $0.order) < ($1.z, $1.order) }) {
            guard let image = sprite.texture?.cgImage() else { continue }
            var transform = CGAffineTransform.identity
            var alpha = sprite.alpha
            var chain: [SKNode] = []
            var node: SKNode? = sprite
            while let n = node, n !== scene {
                chain.append(n)
                node = n.parent
            }
            for n in chain.reversed() {
                transform = transform.translatedBy(x: n.position.x, y: n.position.y)
                    .rotated(by: n.zRotation)
                    .scaledBy(x: n.xScale, y: n.yScale)
                if n !== sprite { alpha *= n.alpha }
            }
            guard alpha > 0.001 else { continue }
            let size = sprite.size
            let rect = CGRect(
                x: -sprite.anchorPoint.x * size.width, y: -sprite.anchorPoint.y * size.height,
                width: size.width, height: size.height)
            context.saveGState()
            context.concatenate(transform)
            context.setAlpha(alpha)
            if sprite.blendMode == .add { context.setBlendMode(.plusLighter) }
            if sprite.colorBlendFactor > 0 {
                context.clip(to: rect, mask: image)
                context.setFillColor(sprite.color.cgColor)
                context.fill(rect)
            } else {
                context.draw(image, in: rect)
            }
            context.restoreGState()
        }
        return context.makeImage()
    }
}
#endif
