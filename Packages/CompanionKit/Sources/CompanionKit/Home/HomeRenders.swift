#if os(iOS) || os(macOS)
import SpriteKit

// Issue #485: the room's furniture is rendered in Blender by Tools/home-room/render_room.py, one PNG per
// layer and time of day, with each layer's place in home-layers.json.

/// The rendered room layers and where each one sits on the plan.
enum HomeRenders {
    private struct Manifest: Decodable {
        struct Rect: Decodable {
            let x: Double
            let y: Double
            let width: Double
            let height: Double
        }

        let layers: [String: [String: Rect]]
    }

    private static let rects: [String: [String: CGRect]] = {
        guard let url = Bundle.module.url(forResource: "home-layers", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let manifest = try? JSONDecoder().decode(Manifest.self, from: data)
        else { return [:] }
        return manifest.layers.mapValues { times in
            times.mapValues { CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
        }
    }()

    /// The layer names the manifest lists.
    static var names: Set<String> { Set(rects.keys) }

    /// The plan rectangle of `layer` at day or night, or `nil` when it wasn't rendered.
    static func rect(_ layer: String, night: Bool) -> CGRect? {
        rects[layer]?[night ? "night" : "day"]
    }

    /// The image of `layer` at day or night, or `nil` when it wasn't rendered.
    static func texture(_ layer: String, night: Bool) -> SKTexture? {
        let name = "home-\(layer)-\(night ? "night" : "day")"
        guard let url = Bundle.module.url(forResource: name, withExtension: "png") else { return nil }
        #if os(iOS)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        #else
        guard let image = NSImage(contentsOf: url) else { return nil }
        #endif
        return SKTexture(image: image)
    }

    /// The layer name of `piece` painted in swatch `index`; swatch 0 is the plain render.
    static func layer(_ name: String, swatch index: Int) -> String {
        index == 0 ? name : "\(name)_\(index)"
    }
}

/// A rendered layer with its day and night images, cross-faded when the time of day changes.
@MainActor
final class HomeLayerNode: SKNode {
    private let day = SKSpriteNode()
    private let night = SKSpriteNode()
    private(set) var layer: String?

    /// A layer that scales and turns about `pivot`, a scene point.
    init(pivot: CGPoint = .zero) {
        super.init()
        position = pivot
        night.zPosition = 0.001
        addChild(day)
        addChild(night)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    /// Shows `layer`; returns `false` when it has no render.
    @discardableResult
    func show(_ layer: String, night isNight: Bool) -> Bool {
        guard layer != self.layer else { return true }
        guard place(day, layer, night: false) else { return false }
        place(night, layer, night: true)
        self.layer = layer
        night.alpha = isNight ? 1 : 0
        return true
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

    @discardableResult
    private func place(_ sprite: SKSpriteNode, _ layer: String, night: Bool) -> Bool {
        guard let rect = HomeRenders.rect(layer, night: night), let texture = HomeRenders.texture(layer, night: night)
        else {
            sprite.texture = nil
            sprite.size = .zero
            return false
        }
        sprite.texture = texture
        sprite.size = rect.size
        sprite.anchorPoint = CGPoint(x: 0, y: 1)
        let corner = HomeGrid.scene(rect.origin)
        sprite.position = CGPoint(x: corner.x - position.x, y: corner.y - position.y)
        return true
    }
}
#endif
