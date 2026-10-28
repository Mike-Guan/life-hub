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
    private let racket = SKSpriteNode()

    private var look = KuroLook.chill
    private var worn: Set<String> = []
    private var items: Set<KuroItem> = []
    private var split: (key: String, parts: (hair: [KuroPart], torso: [KuroPart], head: [KuroPart]))?
    private var shownHead: String?
    private var shownTorso: String?
    private var shownArms: String?
    private var bar = CGPoint.zero

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
        // Her lap is in front of her top.
        sitLegs.zPosition = 0.0045
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
        // In her right hand, the head out past the fist along the arm.
        armR.addChild(racket)
        setTexture(racket, Self.racketTexture, Self.racketRect, pin: .zero)
        racket.position = CGPoint(x: -2, y: -29)
        racket.zPosition = -0.0001
        flip.setScale(Self.scale)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    /// Dresses her in `look`, with the shop items she wears in it.
    func dress(_ look: KuroLook, worn: Set<String>) {
        guard look != self.look || worn != self.worn else { return }
        self.look = look
        self.worn = worn
        items = Set(KuroItem.allCases.filter { worn.contains($0.rawValue) })
    }

    /// Poses the rig for time `t`.
    func apply(_ pose: HakuPose, face: HakuFace, facingRight: Bool, gloves: Bool, t: TimeInterval) {
        let back = pose == .back || pose == .backStand
        let sleeping = pose == .lie || (pose == .doze && HakuNode.dozeNod(t) >= 0.5)
        // The split only changes with her clothes, face or sleep, not every frame.
        let key = "\(look).\(worn.sorted()).\(back ? .back : face).\(sleeping)"
        if split?.key != key {
            let parts = Self.parts(look, items: items, face: back ? .back : face, sleeping: sleeping)
            split = (key, parts)
            hair.isHidden = back || parts.hair.isEmpty
            if !hair.isHidden {
                setTexture(
                    hair, Self.texture(parts.hair, HakuNode.headRect), HakuNode.headRect, pin: CGPoint(x: 60, y: 95))
            }
        }
        guard let parts = split?.parts else { return }
        show(head, key: "head", parts.head, pin: CGPoint(x: 60, y: 95), rect: HakuNode.headRect, shown: &shownHead)
        if back {
            let key = "back.\(Self.sleeve(look))"
            if key != shownTorso {
                shownTorso = key
                setTexture(torso, Self.torsoBack(Self.sleeve(look)), HakuNode.torsoRect, pin: CGPoint(x: 60, y: 138))
            }
        } else {
            show(
                torso, key: "torso", parts.torso, pin: CGPoint(x: 60, y: 138), rect: HakuNode.torsoRect,
                shown: &shownTorso)
        }
        // Only her boxing card wears gloves; on her tennis day the sport spot is a forehand swing.
        let wearsGloves = gloves
        let glove = wearsGloves ? Self.glove(items) : nil
        let armKey = "\(Self.sleeve(look)).\(glove?.rawValue ?? "")"
        if armKey != shownArms {
            shownArms = armKey
            let arm = Self.arm(Self.sleeve(look), glove: glove)
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
        torso.xScale = 1
        racket.isHidden = true
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
                // The guard glove sits by her cheek, beside the chin, in front of her face.
                armL.zRotation = 2.7
                armL.yScale = 0.85
                armL.zPosition = 0.007
                let punch = p > 0.32 && p < 0.58
                armR.zRotation = punch ? 1.62 : 2.35
                armR.yScale = punch ? 1.3 : 1
            } else {
                // A forehand: the racket arm goes back at waist height, sweeps across her front and finishes over
                // the other shoulder, her body turning with it.
                let swing = CGFloat(Self.forehand(t))
                armR.zRotation = Self.backswing + (Self.finish - Self.backswing) * swing
                armR.zPosition = 0.007
                armL.zRotation = 0.5 - 0.3 * swing
                body.zRotation = 0.1 - 0.2 * swing
                torso.xScale = 0.9 + 0.2 * abs(swing - 0.5)
                racket.isHidden = false
            }
        case .sit:
            body.position.y = Self.seatDrop
            legL.isHidden = true
            legR.isHidden = true
            sitLegs.isHidden = false
            sitLegs.position = Self.node(60, 134)
            // Hands resting on her thighs.
            armL.zRotation = 0.3
            armR.zRotation = -0.3
            armL.yScale = 1.2
            armR.yScale = 1.2
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
            // On her back along the bench, pressing the bar like HAKU, a shorter stroke.
            body.zRotation = -.pi / 3
            let lift = Self.barRest + Self.barStroke * CGFloat(HakuNode.pressReach(t))
            bar = CGPoint(x: Self.chest.x + Self.up.x * lift, y: Self.chest.y + Self.up.y * lift)
            let grip = CGPoint(x: Self.along.x * Self.gripHalf, y: Self.along.y * Self.gripHalf)
            reach(armL, from: Self.shoulderL, to: CGPoint(x: bar.x - grip.x, y: bar.y - grip.y))
            reach(armR, from: Self.shoulderR, to: CGPoint(x: bar.x + grip.x, y: bar.y + grip.y))
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

    /// How far through her forehand she is at `t`: 0 racket back, 1 finished over the shoulder. Every 1.6 s: a slow
    /// take-back, a quick sweep, a hold, then back.
    nonisolated static func forehand(_ t: TimeInterval) -> Double {
        let p = t.truncatingRemainder(dividingBy: 1.6)
        switch p {
        case ..<0.5: return 0
        case ..<0.75: return 0.5 - 0.5 * cos((p - 0.5) / 0.25 * .pi)
        case ..<1.1: return 1
        default: return 1 - (0.5 - 0.5 * cos((p - 1.1) / 0.5 * .pi))
        }
    }

    // Arm angles of the forehand: out to her side at the waist, and up across to the other shoulder.
    private static let backswing: CGFloat = 1.25
    private static let finish: CGFloat = -1.9

    /// The middle of the bar she presses, in the coordinates of her parent.
    var barCenter: CGPoint { parentPoint(bar) }

    /// Whether she holds the tablet, and where its middle is in the coordinates of her parent.
    var heldPhone: CGPoint? { tablet.isHidden ? nil : parentPoint(tablet.position) }

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
    private static let chest = CGPoint(x: 0, y: 40)
    private static let barRest: CGFloat = 31
    private static let barStroke: CGFloat = 11
    private static let gripHalf: CGFloat = 13

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
    nonisolated static func parts(
        _ look: KuroLook, items: Set<KuroItem>, face: HakuFace, sleeping: Bool
    )
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
            let offForBed: Set<KuroPart> = [
                .deskGlasses, .itemGlassesRed, .skiGoggles, .maskWork, .itemPhonesMint, .itemPhonesGold,
            ]
            head.formUnion(dressed.filter { isHead($0) && !isFace($0) })
            head.subtract(offForBed)
        }
        // A card prop she wears on her head, like the goggles, is drawn in place of her own.
        let skins = KuroFigure.skins(look, items: items)
        head = Set(head.flatMap { skins[$0] ?? [$0] })
        return (sorted(hair), sorted(torso), sorted(head))
    }

    private nonisolated static let hairParts: Set<KuroPart> = [.hairBack, .itemScrunchie, .tennisPonytail]

    private nonisolated static func isTop(_ part: KuroPart) -> Bool {
        let name = part.rawValue
        guard !name.hasSuffix("_back"), !name.contains("sleeve") else { return false }
        return name.hasPrefix("jacket_") || name.hasPrefix("top_") || name.hasPrefix("base_")
            || name.hasPrefix("set_") && name.hasSuffix("_top") || part == .workBadge
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
            .setPicnicHat, .setRainHat, .deskGlasses, .itemGlassesRed, .skiGoggles, .itemPhonesMint, .itemPhonesGold,
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

    // Her top from behind: the same trapezoid as the front, plain, with a seam.
    private static func torsoBack(_ color: UInt32) -> SKTexture {
        let key = "back.\(color)"
        if let cached = textures[key] { return cached }
        let texture = HomeTextures.texture(HakuNode.torsoRect) { context in
            var shape = Path()
            shape.move(to: CGPoint(x: 31, y: 138))
            shape.addLine(to: CGPoint(x: 36, y: 100))
            shape.addQuadCurve(to: CGPoint(x: 84, y: 100), control: CGPoint(x: 60, y: 92))
            shape.addLine(to: CGPoint(x: 89, y: 138))
            shape.closeSubpath()
            context.fill(shape, with: .color(Color(hex: color)))
            context.stroke(shape, with: .color(KuroPalette.ink), style: StrokeStyle(lineWidth: 3.5, lineJoin: .round))
        }
        textures[key] = texture
        return texture
    }

    /// The part her gloves are drawn like: her own red ones, or the pink or gold ones she wears.
    nonisolated static func glove(_ items: Set<KuroItem>) -> KuroPart {
        KuroFigure.skins(.box, items: items)[.boxGloveR]?.first ?? .boxGloveR
    }

    private static func arm(_ sleeve: UInt32, glove: KuroPart?) -> SKTexture {
        let key = "arm.\(sleeve).\(glove?.rawValue ?? "")"
        if let cached = textures[key] { return cached }
        let texture = HomeTextures.texture(HakuNode.armRect) { context in
            var arm = Path()
            arm.move(to: .zero)
            arm.addQuadCurve(to: CGPoint(x: -2, y: 27), control: CGPoint(x: -2, y: 14))
            context.stroke(arm, with: .color(KuroPalette.ink), style: StrokeStyle(lineWidth: 11.5, lineCap: .round))
            context.stroke(arm, with: .color(Color(hex: sleeve)), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
            let r: CGFloat = glove == nil ? 5 : 8
            let hand = Path(ellipseIn: CGRect(x: -2 - r, y: 29 - r, width: 2 * r, height: 2 * r))
            context.fill(hand, with: .color(glove.map(Self.gloveColor) ?? KuroPalette.skin))
            context.stroke(hand, with: .color(KuroPalette.ink), lineWidth: 2.5)
        }
        textures[key] = texture
        return texture
    }

    private static func gloveColor(_ glove: KuroPart) -> Color {
        switch glove {
        case .itemGlovePinkR: KuroPalette.pink
        case .itemGloveGoldR: KuroPalette.gold
        default: KuroPalette.red
        }
    }

    static let racketRect = CGRect(x: -12, y: -4, width: 24, height: 48)

    /// Her racket, handle at the top so it hangs on from the fist: violet frame, light strings.
    static let racketTexture = HomeTextures.texture(racketRect) { context in
        var handle = Path()
        handle.move(to: CGPoint(x: 0, y: 0))
        handle.addLine(to: CGPoint(x: 0, y: 16))
        context.stroke(handle, with: .color(KuroPalette.ink), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        context.stroke(handle, with: .color(KuroPalette.navy), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        let head = Path(ellipseIn: CGRect(x: -9, y: 16, width: 18, height: 25))
        context.fill(head, with: .color(KuroPalette.goldStrings))
        var strings = Path()
        for x: CGFloat in [-4, 0, 4] {
            strings.move(to: CGPoint(x: x, y: 18))
            strings.addLine(to: CGPoint(x: x, y: 39))
        }
        for y: CGFloat in [23, 28.5, 34] {
            strings.move(to: CGPoint(x: -8, y: y))
            strings.addLine(to: CGPoint(x: 8, y: y))
        }
        context.stroke(strings, with: .color(KuroPalette.ink.opacity(0.35)), lineWidth: 1)
        context.stroke(head, with: .color(KuroPalette.ink), lineWidth: 4.5)
        context.stroke(head, with: .color(KuroPalette.violet), lineWidth: 2)
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

    // Seated legs seen from the front: thighs coming towards us on the seat, knees together, shins down to the floor.
    static let sitTexture = HomeTextures.texture(HakuNode.sitRect) { context in
        let ink = KuroPalette.ink
        for x: CGFloat in [-10.5, 1.5] {
            let shin = Path(roundedRect: CGRect(x: x, y: 14, width: 9, height: 26), cornerRadius: 2)
            context.fill(shin, with: .color(KuroPalette.navy))
            context.stroke(shin, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        }
        for x: CGFloat in [-6, 6] {
            let shoe = Path(ellipseIn: CGRect(x: x - 7, y: 37, width: 14, height: 9))
            context.fill(shoe, with: .color(KuroPalette.white))
            context.stroke(shoe, with: .color(ink), lineWidth: 3)
        }
        for x: CGFloat in [-15, 0] {
            let thigh = Path(roundedRect: CGRect(x: x, y: 0, width: 15, height: 17), cornerRadius: 7)
            context.fill(thigh, with: .color(KuroPalette.navy))
            context.stroke(thigh, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        }
        // A light crease where the thighs meet the knees, so the lap reads as coming forward.
        var knees = Path()
        knees.move(to: CGPoint(x: -12, y: 11))
        knees.addQuadCurve(to: CGPoint(x: 12, y: 11), control: CGPoint(x: 0, y: 14))
        context.stroke(knees, with: .color(KuroPalette.lavender.opacity(0.7)), lineWidth: 1.5)
    }
}

extension KuroHomeNode: HomeFigure {}
#endif
