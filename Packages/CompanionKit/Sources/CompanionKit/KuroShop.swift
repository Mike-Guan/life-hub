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
    // Clothes (商店衣服 pop, Mike approved 2026-10-14): a top or full set worn in one mode.
    case workBlouse = "kuro.top.work.blouse"
    case workVest = "kuro.top.work.vest"
    case chillCardigan = "kuro.top.chill.cardigan"
    case chillHoodie = "kuro.top.chill.hoodie"
    case sideSmock = "kuro.top.side.smock"
    case sideDenim = "kuro.top.side.denim"
    case picnic = "kuro.set.chill.picnic"
    case rain = "kuro.set.work.rain"
    // Sunday items (商店完整目录 v0 §2.4, Mike approved 2026-10-14). The beanie follows with its hat slot.
    case mintTie = "kuro.weekly.hair.mint"
    case bearBlanket = "kuro.weekly.blanket.bear"
    case succulent = "kuro.weekly.room.succulent"
    case cherryClip = "kuro.weekly.hair.cherry"
    case starTie = "kuro.weekly.hair.star"
    case cloud = "kuro.weekly.room.cloud"
    case nightlight = "kuro.weekly.room.nightlight"
    case beanie = "kuro.weekly.hat.beanie"

    /// The look she shows the item in.
    public var look: KuroLook {
        switch self {
        case .flower, .blanket, .spin, .chillCardigan, .chillHoodie, .picnic: .chill
        case .bearBlanket, .succulent, .cloud, .nightlight, .beanie: .chill
        case .scrunchie, .bag, .sakura, .goldRacket, .mintTie, .cherryClip, .starTie: .tennis
        case .lamp, .sideSmock, .sideDenim: .desk
        case .workBlouse, .workVest, .rain: .work
        }
    }

    // UI 五组 Sunday items r1 (位置规划图 §12): the hair pieces go with every look, the succulent also stands where
    // her tennis bag does, and the nightlight also hangs over her desk.
    /// Whether she shows the item in `look`.
    public func shows(in look: KuroLook) -> Bool {
        switch self {
        case .mintTie, .cherryClip, .starTie: true
        case .succulent: look == .chill || look == .tennis
        case .nightlight: look == .chill || look == .desk
        default: self.look == look
        }
    }

    /// Whether the item is a keepsake, granted for a milestone instead of bought.
    public var isKeepsake: Bool {
        switch self {
        case .spin, .sakura, .goldRacket: true
        default: false
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
        case .workBlouse: .topWorkSailor
        case .workVest: .topWorkArgyle
        case .chillCardigan: .topChillStrawberry
        case .chillHoodie: .topChillCathoodie
        case .sideSmock: .topSideGingham
        case .sideDenim: .topSideDenim
        case .picnic: .setPicnicTop
        case .rain: .setRainTop
        case .mintTie: .weeklyHairMintPony
        case .bearBlanket: .weeklyBlanketBear
        case .succulent: .weeklyRoomSucculent
        case .cherryClip: .weeklyHairCherryPony
        case .starTie: .weeklyHairStarPony
        case .cloud: .weeklyRoomCloud
        case .nightlight: .weeklyRoomNightlight
        case .beanie: .weeklyHatBeanie
        }
    }

    /// The parts that draw the item on her; a hair piece goes on her ponytail when `ponytail`, else on the clip
    /// point on the right of her hair.
    func parts(ponytail: Bool) -> Set<KuroPart> {
        switch self {
        case .mintTie: [ponytail ? .weeklyHairMintPony : .weeklyHairMintSide]
        case .cherryClip: [ponytail ? .weeklyHairCherryPony : .weeklyHairCherrySide]
        case .starTie: [ponytail ? .weeklyHairStarPony : .weeklyHairStarSide]
        case .nightlight: [.weeklyRoomNightlightGlow, .weeklyRoomNightlight]
        case .beanie: [.weeklyHatBeanie, .weeklyHatBeaniePom]
        default: [part]
        }
    }

    /// The parts a top or set draws in place of her own top, or nil for anything else.
    var clothes: KuroClothes? {
        switch self {
        case .workBlouse:
            KuroClothes(part, .topWorkSailorRubSleeve, .topWorkSailorInviteSleeve, back: .topWorkSailorBack)
        case .workVest: KuroClothes(part, .topWorkArgyleRubSleeve, .topWorkArgyleInviteSleeve, back: .topWorkArgyleBack)
        case .chillCardigan:
            KuroClothes(
                part, .topChillStrawberryRubSleeve, .topChillStrawberryInviteSleeve, back: .topChillStrawberryBack)
        case .chillHoodie:
            KuroClothes(part, .topChillCathoodieRubSleeve, .topChillCathoodieInviteSleeve, back: .topChillCathoodieBack)
        case .sideSmock:
            KuroClothes(part, .topSideGinghamRubSleeve, .topSideGinghamInviteSleeve, back: .topSideGinghamBack)
        case .sideDenim: KuroClothes(part, .topSideDenimRubSleeve, .topSideDenimInviteSleeve, back: .topSideDenimBack)
        case .picnic:
            KuroClothes(part, .setPicnicRubSleeve, .setPicnicInviteSleeve, back: .setPicnicBack, hat: .setPicnicHat)
        case .rain: KuroClothes(part, .setRainRubSleeve, .setRainInviteSleeve, back: .setRainBack, hat: .setRainHat)
        default: nil
        }
    }

    // One thing on her lap and one on the floor: the cushion is hugged over a blanket, and the succulent takes
    // the tennis bag's spot.
    /// The parts the item takes the place of.
    var replaces: Set<KuroPart> {
        switch self {
        case .sakura: [.tennisHeadband]
        case .goldRacket: [.tennisRacket]
        case .cloud: [.itemBlanket, .weeklyBlanketBear]
        case .succulent: [.itemFlower, .itemBag]
        default: []
        }
    }

    /// The items among `ids`; unknown ids are skipped.
    public static func items(_ ids: Set<String>) -> Set<KuroItem> {
        Set(ids.compactMap(KuroItem.init(rawValue:)))
    }
}

/// The parts a top or full set draws over KURO's own top.
struct KuroClothes: Sendable {
    /// Drawn in place of her look's jacket.
    var top: KuroPart
    /// Drawn in place of her own sleeve when she rubs her eye.
    var rubSleeve: KuroPart
    /// Drawn in place of her own sleeve when she points to invite.
    var inviteSleeve: KuroPart
    /// Drawn in place of her look's jacket when she turns away: only its outline and colour.
    var back: KuroPart
    /// A set's hat, under her cat ears.
    var hat: KuroPart?

    init(_ top: KuroPart, _ rubSleeve: KuroPart, _ inviteSleeve: KuroPart, back: KuroPart, hat: KuroPart? = nil) {
        self.top = top
        self.rubSleeve = rubSleeve
        self.inviteSleeve = inviteSleeve
        self.back = back
        self.hat = hat
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
        if let clothes = item.clothes { return [clothes.top] + (clothes.hat.map { [$0] } ?? []) }
        if item == .nightlight { return [.weeklyRoomNightlightGlow, .weeklyRoomNightlight] }
        if item == .beanie { return [.weeklyHatBeanie, .weeklyHatBeaniePom] }
        guard item == .spin else { return [item.part] }
        return [.hairBack, .earL, .earR, .faceBase, .blush, .eyesHappy, .mouthCat, .hairFringe, .catEars, .itemSpin]
    }

    /// The square of figure space around `parts`, in SVG units.
    nonisolated static func crop(_ parts: [KuroPart]) -> CGRect {
        // A clipped pattern (the gingham checks) reaches far past its clip, so only the clipped area counts.
        let box = parts.flatMap(KuroArt.cachedInks).reduce(CGRect.null) { box, ink in
            box.union(ink.clip.map { ink.path.boundingRect.intersection($0.boundingRect) } ?? ink.path.boundingRect)
        }
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
