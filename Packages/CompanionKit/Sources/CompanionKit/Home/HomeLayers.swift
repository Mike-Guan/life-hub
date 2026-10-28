#if os(iOS) || os(macOS)
import SpriteKit
import SwiftUI

/// One drawn layer of the room.
enum HomeLayer: Hashable, Sendable {
    /// Slab, floor, walls and window, in the wall colour.
    case shell(walls: UInt32)
    /// A piece in its colour; the blanket is pulled up when `covering`.
    case piece(HomePiece, color: UInt32, covering: Bool)
    /// The rug in its style and colour.
    case rug(HomeRug, color: UInt32)
    case item(HomeItem)
    /// The bench's bar, which HAKU lifts off the rack.
    case barbell
    /// The worn gloves on the reward shelf.
    case wornGloves

    /// The plan rectangle the layer is drawn in.
    var rect: CGRect {
        switch self {
        case .shell: HomeGrid.canvas
        case .piece(let piece, _, _): HomeGrid.bounds(piece.boxes, margin: 10)
        case .rug(let rug, _): HomeGrid.bounds([rug.box], margin: 10)
        case .item(let item): HomeGrid.bounds(HomeArt.boxes(item), margin: 10)
        case .barbell: HomeGrid.bounds([HomeArt.barbellBox], margin: 10)
        case .wornGloves: HomeGrid.bounds([HomeArt.wornGlovesBox], margin: 10)
        }
    }

    /// Draws the layer; at night everything it draws is darkened by the same blue.
    func draw(_ context: GraphicsContext, night: Bool) {
        context.drawLayer { layer in
            let pen = IsoPen(context: layer)
            switch self {
            case .shell(let walls): HomeArt.shell(pen, walls: walls, night: night)
            case .piece(let piece, let color, let covering):
                HomeArt.piece(pen, piece, color: color, covering: covering)
            case .rug(let rug, let color): HomeArt.rug(pen, rug, color)
            case .item(let item): HomeArt.item(pen, item)
            case .barbell: HomeArt.barbell(pen)
            case .wornGloves: HomeArt.wornGloves(pen)
            }
            if night {
                layer.blendMode = .sourceAtop
                layer.fill(Path(rect), with: .color(HomeColors.night))
            }
        }
    }
}

/// A drawn layer with its day and night images, cross-faded when the time of day changes.
@MainActor
final class HomeLayerNode: SKNode {
    private let day = SKSpriteNode()
    private let night = SKSpriteNode()
    private(set) var layer: HomeLayer?

    /// A layer that scales and turns about `pivot`, a scene point.
    init(pivot: CGPoint = .zero) {
        super.init()
        position = pivot
        night.zPosition = 0.0001
        addChild(day)
        addChild(night)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    /// Shows `layer`.
    func show(_ layer: HomeLayer, night isNight: Bool) {
        guard layer != self.layer else { return }
        self.layer = layer
        place(day, layer, night: false)
        place(night, layer, night: true)
        night.alpha = isNight ? 1 : 0
    }

    /// Fades to the night or day image.
    func setNight(_ isNight: Bool, duration: TimeInterval) {
        let alpha: CGFloat = isNight ? 1 : 0
        if duration > 0 {
            night.run(SKAction.fadeAlpha(to: alpha, duration: duration))
        } else {
            night.alpha = alpha
        }
    }

    private func place(_ sprite: SKSpriteNode, _ layer: HomeLayer, night: Bool) {
        let rect = layer.rect
        sprite.texture = HomeTextures.texture(rect) { layer.draw($0, night: night) }
        sprite.size = rect.size
        sprite.anchorPoint = CGPoint(x: 0, y: 1)
        let corner = HomeGrid.scene(rect.origin)
        sprite.position = CGPoint(x: corner.x - position.x, y: corner.y - position.y)
    }
}
#endif
