import SwiftUI

// Issue #192. Drawn like the approved shop preview.
/// Something KURO can own from her shop. Raw values are the ledger ids, so never reuse one.
public enum KuroItem: String, CaseIterable, Sendable {
    case flower = "kuro.room.flower"
    case scrunchie = "kuro.hair.scrunchie"
    case blanket = "kuro.blanket.cats"
    case lamp = "kuro.room.lamp"
    case bag = "kuro.bag.tennis"
    case spin = "kuro.celebrate.spin"
    case sakura = "kuro.headband.sakura"
    case goldRacket = "kuro.racket.gold"

    /// The look she shows the item in.
    public var look: KuroLook {
        switch self {
        case .flower, .blanket, .spin: .chill
        case .scrunchie, .bag, .sakura, .goldRacket: .tennis
        case .lamp: .desk
        }
    }

    /// Whether the item is a keepsake, granted for a milestone instead of bought.
    public var isKeepsake: Bool {
        switch self {
        case .spin, .sakura, .goldRacket: true
        case .flower, .scrunchie, .blanket, .lamp, .bag: false
        }
    }

    /// The part that draws the item.
    var part: KuroPart {
        switch self {
        case .flower: .itemFlower
        case .scrunchie: .itemScrunchie
        case .blanket: .itemBlanket
        case .lamp: .itemLamp
        case .bag: .itemBag
        case .spin: .itemSpin
        case .sakura: .itemSakura
        case .goldRacket: .itemGoldRacket
        }
    }

    /// The part of her look the item takes the place of, if any.
    var replaces: KuroPart? {
        switch self {
        case .sakura: .tennisHeadband
        case .goldRacket: .tennisRacket
        default: nil
        }
    }

    /// The items among `ids`; unknown ids are skipped.
    public static func items(_ ids: Set<String>) -> Set<KuroItem> {
        Set(ids.compactMap(KuroItem.init(rawValue:)))
    }
}

/// One of KURO's shop items as a small square picture, for the shop and wardrobe screens.
public struct KuroItemIcon: View {
    let item: KuroItem

    /// - Parameter item: the item to draw.
    public init(item: KuroItem) {
        self.item = item
    }

    public var body: some View {
        Canvas { context, size in
            let parts = Self.parts(item)
            let crop = Self.crop(parts)
            let scale = min(size.width / crop.width, size.height / crop.height)
            context.translateBy(x: (size.width - crop.width * scale) / 2, y: (size.height - crop.height * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -crop.minX, y: -crop.minY)
            for part in parts {
                RunnerDrawing.draw(KuroArt.cachedInks(part), in: context)
            }
        }
        .accessibilityHidden(true)
    }

    // The spin is a celebration, so its picture is her head inside the arcs.
    /// The parts that picture `item`.
    nonisolated static func parts(_ item: KuroItem) -> [KuroPart] {
        guard item == .spin else { return [item.part] }
        return [.hairBack, .earL, .earR, .faceBase, .blush, .eyesHappy, .mouthCat, .hairFringe, .catEars, .itemSpin]
    }

    /// The square of figure space around `parts`, in SVG units.
    nonisolated static func crop(_ parts: [KuroPart]) -> CGRect {
        let box = parts.flatMap(KuroArt.cachedInks).reduce(CGRect.null) { $0.union($1.path.boundingRect) }
        guard !box.isNull else { return KuroArt.bounds }
        let side = max(box.width, box.height) + 8
        return CGRect(x: box.midX - side / 2, y: box.midY - side / 2, width: side, height: side)
    }
}

/// Where KURO's unboxing is at one moment.
struct KuroUnbox: Equatable, Sendable {
    /// The gift box, 0...1, for `GiftBox`.
    var box: Double
    /// How far she has popped out of the box, 0...1 with a little overshoot.
    var popOut: Double
    /// Horizontal scale while she spins, 1 when not spinning.
    var spin: Double
    /// Whether the thought bubble with stars shows.
    var stars: Bool

    /// How long the unboxing plays, in seconds.
    static let duration = 3.2
    /// When her line starts, as a fraction of `duration`.
    static let lineAt = 0.5

    // The box shakes and opens, she pops out acting calm, stars rise in a thought bubble, then the box drops.
    /// The unboxing of `item` at `progress` (0..<1).
    init(_ item: KuroItem, progress: Double) {
        box = progress
        let up = Self.ramp(progress, from: 0.3, to: 0.45)
        popOut = up < 1 ? up * (1 + 0.15 * sin(up * .pi)) : 1
        spin = item == .spin ? cos(2 * .pi * Self.ramp(progress, from: 0.5, to: 0.75)) : 1
        stars = progress >= 0.45
    }

    private static func ramp(_ value: Double, from: Double, to: Double) -> Double {
        min(max((value - from) / (to - from), 0), 1)
    }
}

/// A thought bubble with three twinkling stars: KURO pleased while she acts calm.
struct KuroStarBubble: View {
    var time: TimeInterval

    var body: some View {
        Canvas { context, size in
            // Drawn in a 72 x 54 box, scaled to fit.
            let scale = min(size.width / 72, size.height / 54)
            context.scaleBy(x: scale, y: scale)
            let ink = GraphicsContext.Shading.color(Toy.ink)
            let white = GraphicsContext.Shading.color(.white)
            let dots = [CGRect(x: 2, y: 46, width: 6, height: 6), CGRect(x: 8, y: 34, width: 10, height: 10)]
            for dot in dots.map({ Path(ellipseIn: $0) }) {
                context.fill(dot, with: white)
                context.stroke(dot, with: ink, lineWidth: 2.5)
            }
            let cloud = Path(ellipseIn: CGRect(x: 18, y: 2, width: 52, height: 36))
            context.fill(cloud, with: white)
            context.stroke(cloud, with: ink, lineWidth: 3)
            let stars: [(CGPoint, CGFloat, Double)] = [
                (CGPoint(x: 34, y: 22), 8, 0), (CGPoint(x: 50, y: 12), 6, 0.3), (CGPoint(x: 56, y: 27), 6.5, 0.6),
            ]
            for (center, radius, delay) in stars {
                let beat = (sin((time - delay) * 2 * .pi) + 1) / 2
                let star = Self.star(center: center, radius: radius * (0.65 + 0.45 * beat))
                context.fill(star, with: .color(KuroPalette.yellow))
                context.stroke(star, with: ink, lineWidth: 1.8)
            }
        }
        .aspectRatio(72 / 54, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// A four-pointed star with curved sides.
    static func star(center c: CGPoint, radius r: CGFloat) -> Path {
        let k = r * 0.18
        var path = Path()
        path.move(to: CGPoint(x: c.x, y: c.y - r))
        path.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        path.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        path.closeSubpath()
        return path
    }
}
