#if os(iOS) || os(macOS)
import SpriteKit
import SwiftUI

/// HAKU's face at home, drawn from the companion's own art.
enum HakuFace: CaseIterable, Sendable {
    case idle, focus, chill, happy, tired, yawn, closed, box, back

    var parts: [RunnerPart] {
        let base: [RunnerPart] = [.hairBack, .earL, .earR, .faceBase, .hairFringe, .earringNeon, .maskDown]
        let face: [RunnerPart] =
            switch self {
            case .idle: [.eyesWork]
            case .focus: [.eyesWork, .lidsWork, .browsWork]
            case .chill: [.eyesChill, .mouthSmile]
            case .happy: [.eyesClosed, .mouthSmile]
            case .tired: [.eyesSleepy, .eyebags]
            case .yawn: [.eyesSleepy, .eyebags, .mouthYawn]
            case .closed: [.eyesClosed]
            case .box: [.cateyeL, .cateyeR, .browsBox, .mouthFang, .headband]
            case .back: []
            }
        let parts = self == .back ? [.hairBack, .headBack, .earringNeon] : base + face
        let order = RunnerPart.allCases
        return parts.sorted { (order.firstIndex(of: $0) ?? 0) < (order.firstIndex(of: $1) ?? 0) }
    }

    /// Whether the eyes are open and can blink.
    var blinks: Bool {
        switch self {
        case .idle, .focus, .chill, .tired: true
        default: false
        }
    }
}

/// Textures for the home, drawn once with SwiftUI and kept.
@MainActor
enum HomeTextures {
    static let scale: CGFloat = 3

    /// Renders a drawing in plan or art coordinates; `rect` is the part of that space kept.
    static func image(
        _ rect: CGRect, scale: CGFloat = HomeTextures.scale, _ draw: @escaping (GraphicsContext) -> Void
    ) -> CGImage? {
        let view = Canvas { context, _ in
            var shifted = context
            shifted.translateBy(x: -rect.minX, y: -rect.minY)
            draw(shifted)
        }
        .frame(width: rect.width, height: rect.height)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.cgImage
    }

    static func texture(_ rect: CGRect, _ draw: @escaping (GraphicsContext) -> Void) -> SKTexture {
        guard let image = image(rect, draw) else { return SKTexture() }
        return SKTexture(cgImage: image)
    }

    /// The sprite anchor that puts `point` of `rect` at the node's position.
    static func anchor(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: (point.x - rect.minX) / rect.width, y: (rect.maxY - point.y) / rect.height)
    }
}

/// The full-body HAKU used in the home: the companion's head and tops, with arms and legs.
@MainActor
final class HakuNode: SKNode {
    /// Scene points per art unit; HAKU stands about 95 points tall.
    static let scale: CGFloat = 0.55

    let shadow = SKSpriteNode()
    private let flip = SKNode()
    private let body = SKNode()
    private let legL = SKSpriteNode()
    private let legR = SKSpriteNode()
    private let sitLegs = SKSpriteNode()
    private let torso = SKSpriteNode()
    private let armL = SKSpriteNode()
    private let armR = SKSpriteNode()
    private let head = SKSpriteNode()
    private let phone = SKSpriteNode()

    private var shownFace: HakuFace?
    private var shownOutfit: HomeOutfit?
    private var shownBack: Bool?
    private var shownGloves: Bool?
    private var bar = CGPoint.zero

    // Rig points in art units (SVG space, y down, feet at 172).
    private static func node(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x - 60, y: 172 - y)
    }

    private static let hipL = node(53, 134)
    private static let hipR = node(67, 134)
    private static let hip = node(60, 138)
    private static let shoulderL = node(37, 105)
    private static let shoulderR = node(83, 105)
    private static let neck = node(60, 95)
    private static let seatDrop: CGFloat = -34

    override init() {
        super.init()
        addChild(shadow)
        addChild(flip)
        flip.addChild(body)
        for part in [legL, legR, sitLegs, torso, phone, armL, armR, head] { body.addChild(part) }
        shadow.texture = Self.shadowTexture
        shadow.size = Self.shadowRect.size
        shadow.zPosition = -0.004
        legL.zPosition = 0.001
        legR.zPosition = 0.001
        sitLegs.zPosition = 0.002
        torso.zPosition = 0.004
        head.zPosition = 0.006
        setTexture(legL, Self.legTexture, Self.legRect, pin: .zero)
        setTexture(legR, Self.legTexture, Self.legRect, pin: .zero)
        legR.xScale = -1
        setTexture(sitLegs, Self.sitTexture, Self.sitRect, pin: .zero)
        setTexture(phone, Self.phoneTexture, Self.phoneRect, pin: .zero)
        // Over the chest, under the hands and the head, like the bar.
        phone.zPosition = 0.0055
        flip.setScale(Self.scale)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    /// Poses the rig for time `t`.
    func apply(_ pose: HakuPose, face: HakuFace, outfit: HomeOutfit, facingRight: Bool, gloves: Bool, t: TimeInterval) {
        let back = pose == .back || pose == .backStand
        dress(outfit, back: back, gloves: gloves || pose == .box)
        let shownHead: HakuFace = back ? .back : face
        if shownHead != shownFace {
            shownFace = shownHead
            setTexture(head, Self.head(shownHead), Self.headRect, pin: CGPoint(x: 60, y: 95))
        }
        flip.xScale = facingRight ? Self.scale : -Self.scale

        // Defaults: standing, arms hanging slightly out.
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
        armL.position = Self.shoulderL
        armR.position = Self.shoulderR
        armL.zRotation = -0.12
        armR.zRotation = 0.12
        armL.yScale = 1
        armR.yScale = 1
        armL.zPosition = back ? 0.003 : 0.005
        armR.zPosition = armL.zPosition
        shadow.isHidden = false
        shadow.position = .zero
        shadow.setScale(1)
        phone.isHidden = true

        let breath = CGFloat(sin(t * tau / 2.8))
        switch pose {
        case .stand, .backStand:
            torso.yScale = 1 + 0.015 * breath
            head.position.y += 0.9 * breath
        case .tired:
            torso.yScale = 1 + 0.025 * CGFloat(sin(t * tau / 4.5))
            head.position.y -= 3
            head.zRotation = -0.09
            armL.zRotation = -0.04
            armR.zRotation = 0.04
        case .walk:
            let s = CGFloat(sin(t * tau * 2.2))
            legL.zRotation = 0.45 * s
            legR.zRotation = -0.45 * s
            armL.zRotation = -0.12 - 0.35 * s
            armR.zRotation = 0.12 - 0.35 * s
            body.position.y = 2.5 * abs(s)
        case .happy:
            let phase = t.truncatingRemainder(dividingBy: 0.7) / 0.7
            body.position.y = 24 * CGFloat(sin(.pi * phase))
            armL.zRotation = -2.7
            armR.zRotation = 2.7
            shadow.setScale(1 - 0.3 * CGFloat(sin(.pi * phase)))
        case .stretch:
            armL.zRotation = -2.95
            armR.zRotation = 2.95
            body.yScale = 1.03
        case .box:
            legL.zRotation = -0.22
            legR.zRotation = 0.22
            body.zRotation = -0.05
            let p = t.truncatingRemainder(dividingBy: 0.9) / 0.9
            body.position.y = 1.5 * CGFloat(sin(p * tau * 2))
            armL.zRotation = 2.45
            let punch = p > 0.32 && p < 0.58
            armR.zRotation = punch ? 1.62 : 2.35
            armR.yScale = punch ? 1.3 : 1
        case .sit:
            body.position.y = Self.seatDrop
            legL.isHidden = true
            legR.isHidden = true
            sitLegs.isHidden = false
            sitLegs.position = Self.node(60, 136)
            armL.zRotation = -0.35
            armR.zRotation = 0.35
            body.zRotation = 0.03
            torso.yScale = 1 + 0.02 * CGFloat(sin(t * tau / 3.6))
            head.position.y -= 1
            shadow.isHidden = true
        case .back:
            body.position.y = Self.seatDrop
            legL.isHidden = true
            legR.isHidden = true
            let typing = CGFloat(sin(t * tau * 5))
            armL.zRotation = 0.55 + 0.06 * typing
            armR.zRotation = -0.55 + 0.06 * typing
            head.zRotation = 0.05 * CGFloat(sin(t * tau / 6))
            shadow.isHidden = true
        case .press:
            // On his back along the bench. The bar rests over his chest, below the chin, and goes straight up
            // to lockout; the hands hold it a little apart and the arms stretch to reach them.
            body.zRotation = -.pi / 3
            let lift = Self.barRest + Self.barStroke * CGFloat(Self.pressReach(t))
            bar = CGPoint(x: Self.chest.x + Self.up.x * lift, y: Self.chest.y + Self.up.y * lift)
            let grip = CGPoint(x: Self.along.x * Self.gripHalf, y: Self.along.y * Self.gripHalf)
            reach(armL, from: Self.shoulderL, to: CGPoint(x: bar.x - grip.x, y: bar.y - grip.y))
            reach(armR, from: Self.shoulderR, to: CGPoint(x: bar.x + grip.x, y: bar.y + grip.y))
            shadow.isHidden = true
        case .doze:
            // On his back in bed holding the phone up over his chest; now and then it sinks onto him as he nods off.
            body.zRotation = -.pi / 3
            torso.yScale = 1 + 0.03 * CGFloat(sin(t * tau / 4))
            let nod = CGFloat(Self.dozeNod(t))
            let lift = Self.phoneLift * (1 - nod) + Self.phoneRest * nod
            let held = CGPoint(x: Self.phoneHold.x + Self.up.x * lift, y: Self.phoneHold.y + Self.up.y * lift)
            phone.isHidden = false
            phone.position = held
            phone.yScale = 1 - 0.35 * nod
            // The hands hold the case's sides, tucked behind it.
            let grip = CGPoint(x: Self.along.x * 4, y: Self.along.y * 4)
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
    }

    /// The middle of the bar HAKU presses, in the coordinates of HAKU's parent.
    var barCenter: CGPoint { parentPoint(bar) }

    /// Whether HAKU holds the phone, and where its middle is in the coordinates of HAKU's parent.
    var heldPhone: CGPoint? { phone.isHidden ? nil : parentPoint(phone.position) }

    /// The middle of HAKU's face, in the coordinates of HAKU's parent.
    var faceCenter: CGPoint { parentPoint(Self.node(60, 58)) }

    /// How far HAKU has nodded off over the phone at time `t`: 0 awake and holding it up, 1 asleep with it on his
    /// chest. Every 10 s: 7 s up, a slow sink, a moment asleep, then a jerk back awake.
    nonisolated static func dozeNod(_ t: TimeInterval) -> Double {
        let p = t.truncatingRemainder(dividingBy: 10)
        switch p {
        case ..<7: return 0
        case ..<7.8: return 0.5 - 0.5 * cos((p - 7) / 0.8 * .pi)
        case ..<9.2: return 1
        case ..<9.45: return 1 - (p - 9.2) / 0.25
        default: return 0
        }
    }

    private func parentPoint(_ p: CGPoint) -> CGPoint {
        let q = convert(p, from: body)
        return CGPoint(x: position.x + q.x, y: position.y + q.y)
    }

    // How far up from the chest the phone is held, and where it sinks to when he nods off.
    private static let phoneLift: CGFloat = 18
    private static let phoneRest: CGFloat = 8
    // A little below the chest, so his big head doesn't hide the phone and his arms don't stretch.
    private static let phoneHold = CGPoint(x: 0, y: 30)

    /// How high the bar is during a press at time `t`: 0 resting on the chest, 1 at lockout.
    nonisolated static func pressReach(_ t: TimeInterval) -> Double {
        let phase = t.truncatingRemainder(dividingBy: 2.6) / 2.6
        return 0.5 - 0.5 * cos(phase * 2 * .pi)
    }

    // The press in the lying body's own art units. Straight up on screen, and the bar's direction (the room's
    // x axis), seen from a body turned a third of a turn clockwise.
    private static let up = CGPoint(x: -0.866, y: 0.5)
    private static let along = CGPoint(x: 0.866, y: 0.5)
    // Low on the chest: higher up, the big head would sit on the bar.
    private static let chest = CGPoint(x: 0, y: 40)
    private static let barRest: CGFloat = 31
    private static let barStroke: CGFloat = 13
    private static let gripHalf: CGFloat = 14

    /// Points `arm` from `shoulder` at `hand`, stretching it to get there.
    private func reach(_ arm: SKSpriteNode, from shoulder: CGPoint, to hand: CGPoint) {
        let v = CGPoint(x: hand.x - shoulder.x, y: hand.y - shoulder.y)
        arm.zRotation = atan2(v.x, -v.y)
        // The hand is drawn 29 art units down the arm.
        arm.yScale = hypot(v.x, v.y) / 29
    }

    private func dress(_ outfit: HomeOutfit, back: Bool, gloves: Bool) {
        if outfit != shownOutfit || back != shownBack {
            setTexture(
                torso, back ? Self.torsoBack(outfit) : Self.torso(outfit), Self.torsoRect, pin: CGPoint(x: 60, y: 138))
        }
        if outfit != shownOutfit || gloves != shownGloves {
            let arm = Self.arm(outfit, gloves: gloves)
            setTexture(armL, arm, Self.armRect, pin: .zero)
            setTexture(armR, arm, Self.armRect, pin: .zero)
            armR.xScale = -1
        }
        shownOutfit = outfit
        shownBack = back
        shownGloves = gloves
    }

    private func setTexture(_ sprite: SKSpriteNode, _ texture: SKTexture, _ rect: CGRect, pin: CGPoint) {
        sprite.texture = texture
        sprite.size = rect.size
        sprite.anchorPoint = HomeTextures.anchor(pin, in: rect)
    }

    // MARK: Textures

    static let headRect = CGRect(x: 0, y: -12, width: 120, height: 120)
    static let torsoRect = CGRect(x: 18, y: 84, width: 84, height: 60)
    static let armRect = CGRect(x: -14, y: -8, width: 28, height: 48)
    static let legRect = CGRect(x: -12, y: -4, width: 24, height: 42)
    static let sitRect = CGRect(x: -20, y: -4, width: 40, height: 60)
    static let shadowRect = CGRect(x: -30, y: -9, width: 60, height: 18)

    private static var heads: [HakuFace: SKTexture] = [:]
    private static var tops: [String: SKTexture] = [:]

    static func head(_ face: HakuFace) -> SKTexture {
        if let cached = heads[face] { return cached }
        let parts = face.parts
        let texture = HomeTextures.texture(headRect) { context in
            for part in parts { RunnerDrawing.draw(part, in: context) }
        }
        heads[face] = texture
        return texture
    }

    static func torso(_ outfit: HomeOutfit) -> SKTexture {
        let key = "front.\(outfit.rawValue)"
        if let cached = tops[key] { return cached }
        let texture = HomeTextures.texture(torsoRect) { context in
            for part in outfit.parts {
                RunnerDrawing.draw(part, in: context, fillOverride: part == .jacket ? outfit.base : nil)
            }
        }
        tops[key] = texture
        return texture
    }

    static func torsoBack(_ outfit: HomeOutfit) -> SKTexture {
        let key = "back.\(outfit.rawValue)"
        if let cached = tops[key] { return cached }
        let texture = HomeTextures.texture(torsoRect) { context in
            var shape = Path()
            shape.move(to: CGPoint(x: 30, y: 138))
            shape.addLine(to: CGPoint(x: 36, y: 102))
            shape.addQuadCurve(to: CGPoint(x: 84, y: 102), control: CGPoint(x: 60, y: 92))
            shape.addLine(to: CGPoint(x: 90, y: 138))
            shape.closeSubpath()
            context.fill(shape, with: .color(outfit.base))
            context.stroke(shape, with: .color(RunnerPalette.ink), style: StrokeStyle(lineWidth: 3.5, lineJoin: .round))
            var seam = Path()
            seam.move(to: CGPoint(x: 60, y: 108))
            seam.addLine(to: CGPoint(x: 60, y: 136))
            context.stroke(seam, with: .color(RunnerPalette.ink.opacity(0.35)), lineWidth: 2)
        }
        tops[key] = texture
        return texture
    }

    static func arm(_ outfit: HomeOutfit, gloves: Bool) -> SKTexture {
        let key = "arm.\(outfit.rawValue).\(gloves)"
        if let cached = tops[key] { return cached }
        let texture = HomeTextures.texture(armRect) { context in
            var arm = Path()
            arm.move(to: .zero)
            arm.addQuadCurve(to: CGPoint(x: -3, y: 27), control: CGPoint(x: -3, y: 14))
            context.stroke(arm, with: .color(RunnerPalette.ink), style: StrokeStyle(lineWidth: 13, lineCap: .round))
            context.stroke(arm, with: .color(outfit.base), style: StrokeStyle(lineWidth: 7.5, lineCap: .round))
            let r: CGFloat = gloves ? 8.5 : 5.5
            let hand = Path(ellipseIn: CGRect(x: -3 - r, y: 29 - r, width: 2 * r, height: 2 * r))
            context.fill(hand, with: .color(gloves ? RunnerPalette.boxingRed : RunnerPalette.skin))
            context.stroke(hand, with: .color(RunnerPalette.ink), lineWidth: 2.5)
        }
        tops[key] = texture
        return texture
    }

    static let phoneRect = CGRect(x: -12, y: -17, width: 24, height: 34)

    /// The back of a phone.
    static let phoneTexture = HomeTextures.texture(phoneRect) { context in
        let phone = Path(roundedRect: CGRect(x: -10, y: -15, width: 20, height: 30), cornerRadius: 4)
        // A pink case, so the phone stands out against his green jacket and the blanket.
        context.fill(phone, with: .color(Toy.pink))
        context.stroke(phone, with: .color(RunnerPalette.ink), lineWidth: 2.5)
        context.fill(Path(ellipseIn: CGRect(x: -6, y: -11, width: 5, height: 5)), with: .color(RunnerPalette.ink))
    }

    static let legTexture = HomeTextures.texture(legRect) { context in
        let pants = Path(roundedRect: CGRect(x: -6.5, y: 0, width: 13, height: 27), cornerRadius: 2)
        context.fill(pants, with: .color(RunnerPalette.hood))
        context.stroke(pants, with: .color(RunnerPalette.ink), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        var shoe = Path()
        shoe.move(to: CGPoint(x: -10, y: 35))
        shoe.addQuadCurve(to: CGPoint(x: -2, y: 27), control: CGPoint(x: -10, y: 27))
        shoe.addLine(to: CGPoint(x: 7, y: 27))
        shoe.addLine(to: CGPoint(x: 7, y: 35))
        shoe.closeSubpath()
        context.fill(shoe, with: .color(RunnerPalette.white))
        context.stroke(shoe, with: .color(RunnerPalette.ink), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
    }

    // Seated legs seen from the front: short foreshortened thighs, then shins down to the floor.
    static let sitTexture = HomeTextures.texture(sitRect) { context in
        let ink = RunnerPalette.ink
        for x: CGFloat in [-13.5, 2.5] {
            let shin = Path(roundedRect: CGRect(x: x, y: 10, width: 11, height: 36), cornerRadius: 2)
            context.fill(shin, with: .color(RunnerPalette.hood))
            context.stroke(shin, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        }
        for x: CGFloat in [-8, 8] {
            let shoe = Path(ellipseIn: CGRect(x: x - 8.5, y: 43, width: 17, height: 11))
            context.fill(shoe, with: .color(RunnerPalette.white))
            context.stroke(shoe, with: .color(ink), lineWidth: 3)
        }
        for x: CGFloat in [-16, 1] {
            let thigh = Path(roundedRect: CGRect(x: x, y: -2, width: 15, height: 14), cornerRadius: 5)
            context.fill(thigh, with: .color(RunnerPalette.hood))
            context.stroke(thigh, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        }
    }

    static let shadowTexture = HomeTextures.texture(shadowRect) { context in
        let oval = Path(ellipseIn: CGRect(x: -26, y: -7, width: 52, height: 14))
        context.fill(oval, with: .color(Color(hex: 0x2A1606).opacity(0.3)))
    }
}

/// Small effect sprites: sleep letters, sparkles, a puff of smoke, music notes.
@MainActor
enum HomeEffects {
    static let zzz = HomeTextures.texture(CGRect(x: -10, y: -12, width: 20, height: 24)) { context in
        context.draw(
            Text(verbatim: "Z").font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: 0x7FB2FF)), at: .zero)
    }

    static let sparkle = HomeTextures.texture(CGRect(x: -10, y: -10, width: 20, height: 20)) { context in
        var star = Path()
        star.move(to: CGPoint(x: 0, y: -8))
        star.addQuadCurve(to: CGPoint(x: 8, y: 0), control: .zero)
        star.addQuadCurve(to: CGPoint(x: 0, y: 8), control: .zero)
        star.addQuadCurve(to: CGPoint(x: -8, y: 0), control: .zero)
        star.addQuadCurve(to: CGPoint(x: 0, y: -8), control: .zero)
        context.fill(star, with: .color(Color(hex: 0xFFD23F)))
        context.stroke(star, with: .color(Color(hex: 0x111111)), lineWidth: 1.5)
    }

    static let puff = HomeTextures.texture(CGRect(x: -24, y: -18, width: 48, height: 36)) { context in
        var cloud = Path()
        for (x, y, r) in [(-10.0, 2.0, 10.0), (6.0, -4.0, 12.0), (12.0, 6.0, 9.0), (-2.0, 8.0, 9.0)] {
            cloud.addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
        }
        context.fill(cloud, with: .color(.white))
        context.stroke(cloud, with: .color(Color(hex: 0x111111)), lineWidth: 2)
    }

    static let note = HomeTextures.texture(CGRect(x: -10, y: -14, width: 20, height: 28)) { context in
        var stem = Path()
        stem.move(to: CGPoint(x: 3, y: 6))
        stem.addLine(to: CGPoint(x: 3, y: -10))
        stem.addLine(to: CGPoint(x: 8, y: -7))
        context.stroke(stem, with: .color(Color(hex: 0x111111)), lineWidth: 2.5)
        context.fill(Path(ellipseIn: CGRect(x: -5, y: 2, width: 9, height: 7)), with: .color(Color(hex: 0xFF3EA5)))
    }

    /// A soft round light, tinted by the sprite's colour.
    static let glow = HomeTextures.texture(CGRect(x: -60, y: -60, width: 120, height: 120)) { context in
        let disc = Path(ellipseIn: CGRect(x: -60, y: -60, width: 120, height: 120))
        context.fill(
            disc,
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.9), .white.opacity(0.25), .clear]),
                center: .zero, startRadius: 0, endRadius: 60))
    }
}
#endif
