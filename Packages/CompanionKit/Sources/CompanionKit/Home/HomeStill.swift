#if os(iOS) || os(macOS)
import SpriteKit

// SpriteKit draws nothing without a GPU (the CI simulator, offscreen tests), so a still is composited here with
// Core Graphics from each sprite's texture, in the scene's own order.
extension SKScene {
    /// The scene drawn once, its sprites back to front, `scale` pixels per point; `nil` when no bitmap can be made.
    func still(scale: CGFloat) -> CGImage? {
        let scene = self
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
