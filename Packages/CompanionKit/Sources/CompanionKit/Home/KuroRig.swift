#if os(iOS) || os(macOS)
import SpriteKit
import SwiftUI

/// The second preset character, full body, for the home: her own head, hair and tops from the companion art, with
/// arms and legs, on the same rig points and poses as `HakuNode`.
@MainActor
final class KuroHomeNode: SKNode {
    /// Scene points per art unit, as for HAKU.
    static let scale = HakuNode.scale

    let shadow = SKSpriteNode()
    private let flip = SKNode()
    private let body = SKNode()
    private let legL = SKSpriteNode()
    private let legR = SKSpriteNode()
    private let sitLegs = SKSpriteNode()
    private let hair = SKSpriteNode()
    private let torso = SKSpriteNode()
    private let armL = SKSpriteNode()
    private let armR = SKSpriteNode()
    private let head = SKSpriteNode()
    private let tablet = SKSpriteNode()

    private var look = KuroLook.chill
    private var items: Set<KuroItem> = []
    private var shownHead: String?
    private var shownTorso: String?
    private var shownArms: String?

    private static func node(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x - 60, y: 172 - y)
    }

    private static let hipL = node(53, 134)
    private static let hipR = node(67, 134)
    private static let hip = node(60, 138)
    private static let shoulderL = node(38, 105)
    private static let shoulderR = node(82, 105)
    private static let neck = node(60, 95)
    private static let seatDrop: CGFloat = -34

    override init() {
        super.init()
        addChild(shadow)
        addChild(flip)
        flip.addChild(body)
        for part in [legL, legR, sitLegs, hair, torso, tablet, armL, armR, head] { body.addChild(part) }
        shadow.texture = HakuNode.shadowTexture
        shadow.size = HakuNode.shadowRect.size
        shadow.zPosition = -0.004
        legL.zPosition = 0.001
        legR.zPosition = 0.001
        sitLegs.zPosition = 0.002
        // Her long hair hangs behind her top.
        hair.zPosition = 0.0035
        torso.zPosition = 0.004
        tablet.zPosition = 0.0055
        head.zPosition = 0.006
        setTexture(legL, Self.legTexture, HakuNode.legRect, pin: .zero)
        setTexture(legR, Self.legTexture, HakuNode.legRect, pin: .zero)
        legR.xScale = -1
        setTexture(sitLegs, Self.sitTexture, HakuNode.sitRect, pin: .zero)
        setTexture(tablet, Self.tabletTexture, Self.tabletRect, pin: .zero)
        flip.setScale(Self.scale)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    /// Dresses her in `look`, with the shop items she wears in it.
    func dress(_ look: KuroLook, worn: Set<String>) {
        self.look = look
        items = Set(KuroItem.allCases.filter { worn.contains($0.rawValue) })
    }

    /// Poses the rig for time `t`.
    func apply(_ pose: HakuPose, face: HakuFace, facingRight: Bool, gloves: Bool, t: TimeInterval) {
        let back = pose == .back || pose == .backStand
        let sleeping = pose == .lie || (pose == .doze && HakuNode.dozeNod(t) >= 0.5)
        let parts = Self.parts(look, items: items, face: back ? .back : face, sleeping: sleeping)
        show(head, key: "head", parts.head, pin: CGPoint(x: 60, y: 95), rect: HakuNode.headRect, shown: &shownHead)
        hair.isHidden = back || parts.hair.isEmpty
        if !hair.isHidden {
            setTexture(hair, Self.texture(parts.hair, HakuNode.headRect), HakuNode.headRect, pin: CGPoint(x: 60, y: 95))
        }
        show(torso, key: "torso", parts.torso, pin: CGPoint(x: 60, y: 138), rect: HakuNode.torsoRect, shown: &shownTorso)
        let wearsGloves = gloves || pose == .box
        let armKey = "\(Self.sleeve(look)).\(wearsGloves)"
        if armKey != shownArms {
            shownArms = armKey
            let arm = Self.arm(Self.sleeve(look), gloves: wearsGloves)
            setTexture(armL, arm, HakuNode.armRect, pin: .zero)
            setTexture(armR, arm, HakuNode.armRect, pin: .zero)
            armR.xScale = -1
        }
        flip.xScale = facingRight ? Self.scale : -Self.scale

        let tau = 2 * Double.pi
        body.position = .zero
        body.zRotation = 0
        body.yScale = 1
        legL.isHidden = false
        legR.isHidden = false
        sitLegs.isHidden = true
        legL.position = Self.hipL
        legR.position = Self.hipR
        legL.zRotation = 0
        legR.zRotation = 0
        torso.position = Self.hip
        torso.yScale = 1
        head.position = Self.neck
        head.zRotation = 0
        hair.position = Self.neck
        armL.position = Self.shoulderL
        armR.position = Self.shoulderR
        armL.zRotation = -0.1
        armR.zRotation = 0.1
        armL.yScale = 1
        armR.yScale = 1
        armL.zPosition = back ? 0.003 : 0.005
        armR.zPosition = armL.zPosition
        shadow.isHidden = false
        shadow.position = .zero
        shadow.setScale(1)
        tablet.isHidden = true

        let breath = CGFloat(sin(t * tau / 2.8))
        switch pose {
        case .stand, .backStand:
            torso.yScale = 1 + 0.015 * breath
            head.position.y += 0.9 * breath
            // Her hands meet in front of her, a little shy.
            if !back {
                armL.zRotation = 0.28
                armR.zRotation = -0.28
            }
        case .tired:
            torso.yScale = 1 + 0.025 * CGFloat(sin(t * tau / 4.5))
            head.position.y -= 3
            head.zRotation = 0.09
            armL.zRotation = -0.03
            armR.zRotation = 0.03
        case .walk:
            // Smaller steps than HAKU's, a touch quicker.
            let s = CGFloat(sin(t * tau * 2.4))
            legL.zRotation = 0.35 * s
            legR.zRotation = -0.35 * s
            armL.zRotation = -0.1 - 0.28 * s
            armR.zRotation = 0.1 - 0.28 * s
            body.position.y = 2 * abs(s)
        case .happy:
            let phase = t.truncatingRemainder(dividingBy: 0.7) / 0.7
            body.position.y = 18 * CGFloat(sin(.pi * phase))
            armL.zRotation = -2.6
            armR.zRotation = 2.6
            shadow.setScale(1 - 0.25 * CGFloat(sin(.pi * phase)))
        case .stretch:
            armL.zRotation = -2.95
            armR.zRotation = 2.95
            body.yScale = 1.03
        case .box:
            // Her sport on the floor spot: a forehand shadow swing, or jabs in her boxing gloves.
            legL.zRotation = -0.2
            legR.zRotation = 0.2
            let p = t.truncatingRemainder(dividingBy: 0.9) / 0.9
            body.position.y = 1.5 * CGFloat(sin(p * tau * 2))
            if wearsGloves {
                armL.zRotation = 2.45
                let punch = p > 0.32 && p < 0.58
                armR.zRotation = punch ? 1.62 : 2.35
                armR.yScale = punch ? 1.3 : 1
            } else {
                let swing = CGFloat(0.5 - 0.5 * cos(p * tau))
                armR.zRotation = 0.6 + 1.4 * swing
                armL.zRotation = -0.5
                body.zRotation = -0.06 + 0.12 * swing
            }
        case .sit:
            body.position.y = Self.seatDrop
            legL.isHidden = true
            legR.isHidden = true
            sitLegs.isHidden = false
            sitLegs.position = Self.node(60, 136)
            // Hands folded on her lap.
            armL.zRotation = 0.45
            armR.zRotation = -0.45
            body.zRotation = -0.03
            torso.yScale = 1 + 0.02 * CGFloat(sin(t * tau / 3.6))
            head.position.y -= 1
            head.zRotation = 0.04
            shadow.isHidden = true
        case .back:
            body.position.y = Self.seatDrop
            legL.isHidden = true
            legR.isHidden = true
            let drawing = CGFloat(sin(t * tau * 1.6))
            armL.zRotation = 0.5
            armR.zRotation = -0.6 + 0.08 * drawing
            head.zRotation = 0.04 * CGFloat(sin(t * tau / 6))
            shadow.isHidden = true
        case .press:
            body.zRotation = -.pi / 3
            armL.zRotation = 3.0
            armR.zRotation = -3.0
            shadow.isHidden = true
        case .doze:
            // On her back in bed, the tablet held up over her chest; now and then it sinks onto her as she nods off.
            body.zRotation = -.pi / 3
            torso.yScale = 1 + 0.03 * CGFloat(sin(t * tau / 4))
            let nod = CGFloat(HakuNode.dozeNod(t))
            let lift = Self.tabletLift * (1 - nod) + Self.tabletRest * nod
            let held = CGPoint(x: Self.tabletHold.x + Self.up.x * lift, y: Self.tabletHold.y + Self.up.y * lift)
            tablet.isHidden = false
            tablet.position = held
            tablet.yScale = 1 - 0.35 * nod
            let grip = CGPoint(x: Self.along.x * 9, y: Self.along.y * 9)
            reach(armL, from: Self.shoulderL, to: CGPoint(x: held.x - grip.x, y: held.y - grip.y))
            reach(armR, from: Self.shoulderR, to: CGPoint(x: held.x + grip.x, y: held.y + grip.y))
            shadow.isHidden = true
        case .lie:
            body.zRotation = -.pi / 3
            torso.yScale = 1 + 0.03 * CGFloat(sin(t * tau / 4))
            armL.zRotation = -0.05
            armR.zRotation = 0.05
            shadow.isHidden = true
        case .dangle:
            let sway = CGFloat(sin(t * tau * 0.8))
            let kick = CGFloat(sin(t * tau * 2.6))
            body.zRotation = 0.1 * sway
            legL.zRotation = 0.3 * kick
            legR.zRotation = -0.3 * kick
            armL.zRotation = -2.8
            armR.zRotation = 2.8
            shadow.isHidden = true
        }
        hair.position = head.position
        hair.zRotation = head.zRotation
    }

    /// Whether she holds the tablet, and where its middle is in the coordinates of her parent.
    var heldTablet: CGPoint? { tablet.isHidden ? nil : parentPoint(tablet.position) }

    /// The middle of her face, in the coordinates of her parent.
    var faceCenter: CGPoint { parentPoint(Self.node(60, 62)) }

    private func parentPoint(_ p: CGPoint) -> CGPoint {
        let q = convert(p, from: body)
        return CGPoint(x: position.x + q.x, y: position.y + q.y)
    }

    // The tablet in the lying body's own art units, like HAKU's phone; it is wider, so the hands hold it further out.
    private static let tabletLift: CGFloat = 18
    private static let tabletRest: CGFloat = 8
    private static let tabletHold = CGPoint(x: 0, y: 30)
    private static let up = CGPoint(x: -0.866, y: 0.5)
    private static let along = CGPoint(x: 0.866, y: 0.5)

    private func reach(_ arm: SKSpriteNode, from shoulder: CGPoint, to hand: CGPoint) {
        let v = CGPoint(x: hand.x - shoulder.x, y: hand.y - shoulder.y)
        arm.zRotation = atan2(v.x, -v.y)
        arm.yScale = hypot(v.x, v.y) / 29
    }

    private func show(
        _ sprite: SKSpriteNode, key: String, _ parts: [KuroPart], pin: CGPoint, rect: CGRect, shown: inout String?
    ) {
        let id = key + parts.map(\.rawValue).joined(separator: ",")
        guard id != shown else { return }
        shown = id
        setTexture(sprite, Self.texture(parts, rect), rect, pin: pin)
    }

    private func setTexture(_ sprite: SKSpriteNode, _ texture: SKTexture, _ rect: CGRect, pin: CGPoint) {
        sprite.texture = texture
        sprite.size = rect.size
        sprite.anchorPoint = HomeTextures.anchor(pin, in: rect)
    }

    // MARK: Parts

    /// Her parts for the home, split into the hair behind her, her top and her head. What she holds in the
    /// companion (cup, tablet, racket, books) stays out: in the home her things are in the room.
    nonisolated static func parts(_ look: KuroLook, items: Set<KuroItem>, face: HakuFace, sleeping: Bool)
        -> (hair: [KuroPart], torso: [KuroPart], head: [KuroPart])
    {
        var pose = KuroPose(look: look, energy: nil)
        pose.items = items
        switch face {
        case .idle, .chill, .back: break
        case .focus:
            pose.eyes = .down
            pose.calm = true
        case .happy: pose.eyes = .happy
        case .tired:
            pose.eyes = .drowsy
            pose.tired = true
        case .yawn:
            pose.eyes = .drowsy
            pose.tired = true
            pose.mouthO = true
        case .closed: pose.eyes = .closed
        case .box: pose.eyes = .bright
        }
        // Asleep in bed: the companion's nap face, eyes shut and a sleepy mouth.
        if sleeping {
            pose.napping = true
        }
        let visible = Set(KuroFigure.parts(for: sleeping ? .chill : look, pose: pose))
        var plain = KuroPose(look: look, energy: nil)
        plain.items = items
        let dressed = Set(KuroFigure.parts(for: look, pose: plain))
        let order = KuroPart.allCases
        func sorted(_ set: Set<KuroPart>) -> [KuroPart] {
            set.sorted { (order.firstIndex(of: $0) ?? 0) < (order.firstIndex(of: $1) ?? 0) }
        }
        let hair = dressed.filter(hairParts.contains)
        let torso = dressed.filter(isTop)
        if face == .back {
            return (sorted(hair), sorted(torso), sorted(hair.filter { $0 != .hairBack }.union([.backHead])))
        }
        var head = visible.filter { isHead($0) }
        // Asleep she keeps what her look wears on her head, but takes off glasses, goggles and the mask for bed.
        if sleeping {
            let offForBed: Set<KuroPart> = [.deskGlasses, .skiGoggles, .maskWork]
            head.formUnion(dressed.filter { isHead($0) && !isFace($0) })
            head.subtract(offForBed)
        }
        return (sorted(hair), sorted(torso), sorted(head))
    }

    private nonisolated static let hairParts: Set<KuroPart> = [.hairBack, .itemScrunchie, .tennisPonytail]

    private nonisolated static func isTop(_ part: KuroPart) -> Bool {
        let name = part.rawValue
        guard !name.hasSuffix("_back"), !name.contains("sleeve") else { return false }
        return name.hasPrefix("jacket_") || name.hasPrefix("top_") || name.hasPrefix("base_")
            || name.hasPrefix("set_") && name.hasSuffix("_top") || part == .boxShoulderTowel || part == .workBadge
    }

    private nonisolated static func isFace(_ part: KuroPart) -> Bool {
        let name = part.rawValue
        return name.hasPrefix("eyes_") || name.hasPrefix("mouth_") || part == .napMouth || part == .blush
            || part == .cheeksFull
    }

    private nonisolated static func isHead(_ part: KuroPart) -> Bool {
        let name = part.rawValue
        if isFace(part) { return true }
        if name.hasPrefix("weekly_hair_") || name.hasPrefix("weekly_hat_") { return true }
        let head: Set<KuroPart> = [
            .earL, .earR, .faceBase, .maskWork, .hairFringe, .catEars, .tennisHeadband, .boxHeadband, .itemSakura,
            .setPicnicHat, .setRainHat, .deskGlasses, .skiGoggles,
        ]
        return head.contains(part)
    }

    // MARK: Textures

    private static var textures: [String: SKTexture] = [:]

    private static func texture(_ parts: [KuroPart], _ rect: CGRect) -> SKTexture {
        let key = parts.map(\.rawValue).joined(separator: ",") + "@\(rect.minY)"
        if let cached = textures[key] { return cached }
        let texture = HomeTextures.texture(rect) { context in
            for part in parts { RunnerDrawing.draw(KuroArt.inks(part), in: context) }
        }
        textures[key] = texture
        return texture
    }

    /// The colour of her sleeves in `look`, matching its top.
    static func sleeve(_ look: KuroLook) -> UInt32 {
        switch look {
        case .work: 0x2D3250
        case .chill, .study, .music: 0xC9B8FF
        case .tennis, .fitness, .dance, .ski: 0xFFFFFF
        case .desk: 0xF2E8FF
        case .box: 0x7B5CFF
        case .art: 0xFFE14D
        }
    }

    private static func arm(_ sleeve: UInt32, gloves: Bool) -> SKTexture {
        let key = "arm.\(sleeve).\(gloves)"
        if let cached = textures[key] { return cached }
        let texture = HomeTextures.texture(HakuNode.armRect) { context in
            var arm = Path()
            arm.move(to: .zero)
            arm.addQuadCurve(to: CGPoint(x: -2, y: 27), control: CGPoint(x: -2, y: 14))
            context.stroke(arm, with: .color(KuroPalette.ink), style: StrokeStyle(lineWidth: 11.5, lineCap: .round))
            context.stroke(arm, with: .color(Color(hex: sleeve)), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
            let r: CGFloat = gloves ? 8 : 5
            let hand = Path(ellipseIn: CGRect(x: -2 - r, y: 29 - r, width: 2 * r, height: 2 * r))
            context.fill(hand, with: .color(gloves ? KuroPalette.red : KuroPalette.skin))
            context.stroke(hand, with: .color(KuroPalette.ink), lineWidth: 2.5)
        }
        textures[key] = texture
        return texture
    }

    static let tabletRect = CGRect(x: -16, y: -13, width: 32, height: 26)

    /// The back of her tablet, landscape, in its lilac case.
    static let tabletTexture = HomeTextures.texture(tabletRect) { context in
        let tablet = Path(roundedRect: CGRect(x: -14, y: -11, width: 28, height: 22), cornerRadius: 4)
        context.fill(tablet, with: .color(KuroPalette.lilac))
        context.stroke(tablet, with: .color(KuroPalette.ink), lineWidth: 2.5)
        context.fill(Path(ellipseIn: CGRect(x: -10, y: -7, width: 4, height: 4)), with: .color(KuroPalette.ink))
        var cat = Path()
        cat.move(to: CGPoint(x: 1, y: 2))
        cat.addLine(to: CGPoint(x: 3, y: -2))
        cat.addLine(to: CGPoint(x: 5, y: 1))
        cat.addLine(to: CGPoint(x: 7, y: -2))
        cat.addLine(to: CGPoint(x: 9, y: 2))
        context.stroke(cat, with: .color(KuroPalette.violet), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
    }

    // Slim dark leggings and white shoes with a lilac stripe.
    static let legTexture = HomeTextures.texture(HakuNode.legRect) { context in
        let legs = Path(roundedRect: CGRect(x: -5.5, y: 0, width: 11, height: 27), cornerRadius: 2)
        context.fill(legs, with: .color(KuroPalette.navy))
        context.stroke(legs, with: .color(KuroPalette.ink), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        var shoe = Path()
        shoe.move(to: CGPoint(x: -9, y: 35))
        shoe.addQuadCurve(to: CGPoint(x: -2, y: 27), control: CGPoint(x: -9, y: 27))
        shoe.addLine(to: CGPoint(x: 6, y: 27))
        shoe.addLine(to: CGPoint(x: 6, y: 35))
        shoe.closeSubpath()
        context.fill(shoe, with: .color(KuroPalette.white))
        context.stroke(shoe, with: .color(KuroPalette.ink), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        var stripe = Path()
        stripe.move(to: CGPoint(x: -4, y: 31))
        stripe.addLine(to: CGPoint(x: 4, y: 31))
        context.stroke(stripe, with: .color(KuroPalette.lavender), lineWidth: 2)
    }

    // Seated legs seen from the front, knees together.
    static let sitTexture = HomeTextures.texture(HakuNode.sitRect) { context in
        let ink = KuroPalette.ink
        for x: CGFloat in [-11.5, 1.5] {
            let shin = Path(roundedRect: CGRect(x: x, y: 10, width: 10, height: 36), cornerRadius: 2)
            context.fill(shin, with: .color(KuroPalette.navy))
            context.stroke(shin, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        }
        for x: CGFloat in [-6.5, 6.5] {
            let shoe = Path(ellipseIn: CGRect(x: x - 7.5, y: 43, width: 15, height: 10))
            context.fill(shoe, with: .color(KuroPalette.white))
            context.stroke(shoe, with: .color(ink), lineWidth: 3)
        }
        for x: CGFloat in [-14, 0] {
            let thigh = Path(roundedRect: CGRect(x: x, y: -2, width: 14, height: 14), cornerRadius: 5)
            context.fill(thigh, with: .color(KuroPalette.navy))
            context.stroke(thigh, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        }
    }
}
#endif
