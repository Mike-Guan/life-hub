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
