#if os(iOS) || os(macOS)
import HubCore
import SpriteKit
import SwiftUI

/// The isometric room with the character in it. SpriteKit draws and moves; `HomeModel` decides.
@MainActor
final class HomeScene: SKScene {
    let model: HomeModel
    /// The character's figure: HAKU's, or the second preset character's once hers is drawn.
    let haku: any HomeFigure

    private var pieces: [HomePiece: HomeLayerNode] = [:]
    private var itemNodes: [HomeItem: HomeLayerNode] = [:]
    private var barbell: HomeLayerNode?
    private let phoneGlow = SKSpriteNode(texture: HomeEffects.glow)
    private let shell = HomeLayerNode()
    private let skyDay = SKSpriteNode()
    private let skyNight = SKSpriteNode()
    private let clothes = SKSpriteNode()
    private let screen = SKSpriteNode()
    private var monitorLight = SKSpriteNode()
    private var nightLights: [SKSpriteNode] = []
    private var daylight = SKSpriteNode()

    // Where HAKU is and where he is going.
    private var point = HomeSpot.hub
    private var reached: HomeSpot? = .idle
    private var target: HomeSpot = .idle
    private var targetDrop: GridPoint?
    private var walk: HomeWalk?
    private var walked = 0.0
    private var facingRight = true
    private var landsDirectly = false
    private var dragPoint: CGPoint?

    private var clock: TimeInterval = 0
    /// When HAKU got into bed, on the scene's clock.
    private var restSince: TimeInterval?
    private var lastTime: TimeInterval?
    private var oneOff: (pose: HakuPose?, face: HakuFace, until: TimeInterval)?
    private var hopStart: TimeInterval?
    private var shakeStart: TimeInterval?
    private var bagHit: TimeInterval?
    private var lastPunchPhase = 0.0
    private var nextEffect: TimeInterval = 0

    // What the drawing shows now, to redraw only what changed.
    private var shownColors: [UInt32]?
    private var shownOutfits: [HomeOutfit] = []
    private var shownNight: Bool?
    private var shownScreen: HomeScreen?
    private var shownCovering: Bool?

    static let walkSpeed = 2.6
    /// Where the middle of the bar sits on the rack, in scene coordinates.
    static let rackedBar = HomeGrid.scene(HomeGrid.plan(HomeArt.racked))

    /// The spot HAKU has reached, or `nil` while walking, carried or dropped on the floor.
    var spotReached: HomeSpot? { reached }
    var isWalking: Bool { walk != nil }

    init(model: HomeModel) {
        self.model = model
        haku = Self.figure(for: model.snapshot.persona)
        super.init(size: HomeGrid.canvas.size)
        anchorPoint = .zero
        scaleMode = .aspectFit
        backgroundColor = .clear
        build()
        sync(animated: false)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    // MARK: Building

    private func build() {
        addChild(islandShadow())
        shell.zPosition = -10
        addChild(shell)
        // The sky shows through the window cut out of the wall.
        for sprite in [skyDay, skyNight] {
            sprite.zPosition = -10.5
            addChild(sprite)
        }
        let w = HomeArt.window
        let windowRect = HomeGrid.bounds([GridBox(x0: w.u0, y0: 0, x1: w.u1, y1: 0.1, z0: w.z0, z1: w.z1)])
        place(skyDay, windowRect, HomeTextures.texture(windowRect) { HomeArt.sky(IsoPen(context: $0), night: false) })
        place(skyNight, windowRect, HomeTextures.texture(windowRect) { HomeArt.sky(IsoPen(context: $0), night: true) })

        for piece in HomePiece.allCases {
            let node = HomeLayerNode()
            node.zPosition = CGFloat(piece.depth)
            pieces[piece] = node
            addChild(node)
        }
        clothes.zPosition = CGFloat(HomePiece.wardrobe.depth) + 0.01
        addChild(clothes)

        let screenRect = HomeArt.screenRect
        screen.zPosition = CGFloat(HomePiece.desk.depth) + 0.05
        place(
            screen, screenRect, HomeTextures.texture(screenRect) { HomeArt.screen(IsoPen(context: $0), content: .off) })
        addChild(screen)
        monitorLight = glow(GridPoint(x: 0.6, y: 2.0, z: 2.1), 0x3EF0FF, 120)
        // The lamps, the vending machine and the moon at night; the sun through the window by day.
        let lights: [(GridPoint, UInt32, CGFloat)] = [
            (GridPoint(x: 0.66, y: 1.0, z: 2.0), 0xFFC66B, 170),
            (GridPoint(x: 0.5, y: 8.4, z: 2.0), 0xFF5A7A, 190),
            (GridPoint(x: 9.45, y: 4.05, z: 1.4), 0xFFC66B, 160),
            (GridPoint(x: 9.5, y: 1.4, z: 2.4), 0x7CFF4F, 120),
            (GridPoint(x: 2.3, y: 0.4, z: 3.4), 0x9AA8FF, 170),
        ]
        nightLights = lights.map { glow($0.0, $0.1, $0.2) }
        daylight = glow(GridPoint(x: 2.3, y: 1.0, z: 2.6), 0xFFF1C2, 300)

        addChild(haku)
    }

    /// The figure for `persona`; HAKU's stands in until the second preset character's is drawn.
    static func figure(for persona: Persona) -> any HomeFigure {
        switch persona {
        case .haku, .kuro: HakuNode()
        }
    }

    /// The hard shadow the floating room casts on the page.
    private func islandShadow() -> SKSpriteNode {
        let n = HomeGrid.size
        let t = HomeGrid.wallThickness
        let z = -HomeGrid.slab
        let corners = [(-t, -t), (n, -t), (n, n), (-t, n)].map { x, y in
            let p = HomeGrid.plan(x, y, z)
            return CGPoint(x: p.x, y: p.y + 7)
        }
        let rect = HomeGrid.canvas
        let shadow = SKSpriteNode()
        place(
            shadow, rect,
            HomeTextures.texture(rect) {
                IsoPen(context: $0).polygon(corners, Color(hex: 0x2D2416).opacity(0.16), line: 0)
            })
        shadow.zPosition = -11
        return shadow
    }

    private func glow(_ at: GridPoint, _ hex: UInt32, _ size: CGFloat) -> SKSpriteNode {
        let sprite = SKSpriteNode(texture: HomeEffects.glow)
        sprite.size = CGSize(width: size, height: size)
        sprite.position = HomeGrid.scene(HomeGrid.plan(at))
        sprite.color = UIColorBridge.color(hex)
        sprite.colorBlendFactor = 1
        sprite.blendMode = .add
        sprite.alpha = 0
        sprite.zPosition = 51
        addChild(sprite)
        return sprite
    }

    /// Puts `sprite` over `rect` of the plan, pinned at `pin` (the rect's middle by default).
    private func place(_ sprite: SKSpriteNode, _ rect: CGRect, _ texture: SKTexture, pin: CGPoint? = nil) {
        let p = pin ?? CGPoint(x: rect.midX, y: rect.midY)
        sprite.texture = texture
        sprite.size = rect.size
        sprite.anchorPoint = HomeTextures.anchor(p, in: rect)
        sprite.position = HomeGrid.scene(p)
    }

    /// The layer that shows `piece` with the colours picked now.
    private func layer(_ piece: HomePiece, covering: Bool) -> HomeLayer {
        let color: UInt32 =
            switch piece {
            case .sofaBack, .sofaFarArm, .sofaSeat, .sofaNearArm: model.color(.sofa)
            case .rug: model.color(.rug)
            case .blanket: model.color(.bed)
            default: 0
            }
        return .piece(piece, color: color, covering: piece == .blanket && covering)
    }

    // MARK: Syncing with the model

    /// Brings the drawing up to date with the model.
    func sync(animated: Bool = true) {
        let colors = HomePaintable.allCases.map(model.color)
        if colors != shownColors {
            redraw(flashing: shownColors != nil)
            shownColors = colors
        }
        let outfits = model.ownedOutfits
        if outfits != shownOutfits {
            shownOutfits = outfits
            let rect = HomeGrid.bounds(HomePiece.wardrobe.boxes)
            place(clothes, rect, HomeTextures.texture(rect) { HomeArt.clothes(IsoPen(context: $0), owned: outfits) })
        }
        let items = model.items
        for item in items where itemNodes[item] == nil {
            addItem(item)
        }
        for (item, node) in itemNodes where !items.contains(item) {
            node.removeFromParent()
            itemNodes[item] = nil
        }
        if items.contains(.bench), barbell == nil {
            let bar = HomeLayerNode(pivot: Self.rackedBar)
            bar.show(.barbell, night: model.isNight)
            barbell = bar
            addChild(bar)
        } else if !items.contains(.bench) {
            barbell?.removeFromParent()
            barbell = nil
        }
        if model.isNight != shownNight {
            setNight(model.isNight, animated: animated && shownNight != nil)
            shownNight = model.isNight
        }
        if model.spot != target || model.dropPoint != targetDrop {
            head(to: model.spot, drop: model.dropPoint)
        }
        for cue in model.takeCues() { play(cue, animated: animated) }
        updateScreen()
    }

    private func redraw(flashing: Bool) {
        let night = model.isNight
        shell.show(.shell(walls: model.color(.walls)), night: night)
        for (piece, node) in pieces {
            node.show(layer(piece, covering: shownCovering == true), night: night)
        }
        if flashing { flash() }
    }

    private func drawBlanket(covering: Bool) {
        guard covering != shownCovering else { return }
        shownCovering = covering
        pieces[.blanket]?.show(layer(.blanket, covering: covering), night: model.isNight)
    }

    private func addItem(_ item: HomeItem) {
        let s = item.spot
        let node = HomeLayerNode(pivot: HomeGrid.scene(HomeGrid.plan(s.x, s.y, s.z)))
        node.show(.item(item), night: model.isNight)
        node.zPosition = CGFloat(item.depth)
        itemNodes[item] = node
        addChild(node)
    }

    private func setNight(_ night: Bool, animated: Bool) {
        let duration = animated ? 1.2 : 0
        func fade(_ node: SKNode, _ alpha: CGFloat) {
            if duration > 0 {
                node.run(SKAction.fadeAlpha(to: alpha, duration: duration))
            } else {
                node.alpha = alpha
            }
        }
        fade(skyNight, night ? 1 : 0)
        fade(skyDay, night ? 0 : 1)
        fade(clothes, night ? 0.6 : 1)
        fade(daylight, night ? 0 : 0.35)
        for light in nightLights { fade(light, night ? 0.85 : 0) }
        for node in [shell] + Array(pieces.values) + Array(itemNodes.values) + [barbell].compactMap({ $0 }) {
            node.setNight(night, duration: duration)
        }
    }

    private func updateScreen() {
        let content: HomeScreen =
            switch reached {
            case .work?: .code
            case .side?: .sketch
            default: .off
            }
        guard content != shownScreen else { return }
        shownScreen = content
        let rect = HomeArt.screenRect
        screen.texture = HomeTextures.texture(rect) { HomeArt.screen(IsoPen(context: $0), content: content) }
        monitorLight.alpha = content == .off ? 0 : (model.isNight ? 0.8 : 0.35)
    }

    /// A short white flash over the room after a colour change.
    private func flash() {
        let sprite = SKSpriteNode(color: .white, size: size)
        sprite.anchorPoint = .zero
        sprite.alpha = 0.25
        sprite.zPosition = 60
        sprite.blendMode = .add
        addChild(sprite)
        sprite.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.35), SKAction.removeFromParent()]))
    }

    // MARK: Walking

    private func head(to spot: HomeSpot, drop: GridPoint?) {
        target = spot
        targetDrop = drop
        if let drop {
            walk = nil
            point = drop
            reached = nil
            landsDirectly = false
            return
        }
        if landsDirectly {
            landsDirectly = false
            arrive()
            return
        }
        guard reached != spot else { return }
        let stops = spot.path(from: point, leaving: reached, nav: .room(items: model.items))
        walk = HomeWalk(stops: stops)
        walked = 0
        reached = nil
    }

    private func arrive() {
        walk = nil
        point = target.point
        reached = target
        restSince = target == .rest ? clock : nil
        if let right = target.facesRight { facingRight = right }
        updateScreen()
    }

    /// Puts HAKU straight at the model's spot, for still frames.
    func settle() {
        target = model.spot
        targetDrop = model.dropPoint
        if let drop = model.dropPoint {
            point = drop
            reached = nil
        } else {
            arrive()
        }
    }

    // MARK: Frames

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime.map { min(0.05, max(0, currentTime - $0)) } ?? 0
        lastTime = currentTime
        step(dt)
    }

    /// Advances the room by `dt` seconds.
    func step(_ dt: TimeInterval) {
        clock += dt
        model.tick(dt)
        if let walk {
            walked += dt * Self.walkSpeed
            let (p, heading) = walk.position(after: walked)
            point = p
            let dx = HomeGrid.plan(heading).x - HomeGrid.plan(p).x
            if abs(dx) > 0.5 { facingRight = dx > 0 }
            if walked >= walk.length { arrive() }
        }
        poseHaku()
        spawnEffects()
    }

    /// Poses HAKU for a still frame at time `t`.
    func pose(at t: TimeInterval) {
        clock = t
        poseHaku()
    }

    private func poseHaku() {
        let tired = model.isLow
        var pose: HakuPose = tired ? .tired : .stand
        var face: HakuFace = tired ? .tired : .idle
        var depth = HomeGrid.walkingDepth(point)
        var facing = facingRight
        if dragPoint != nil {
            pose = .dangle
            face = .yawn
        } else if walk != nil {
            pose = .walk
        } else if let spot = reached {
            pose = spot.pose
            depth = spot.depth ?? depth
            switch spot {
            case .work, .side: face = .focus
            case .sofa: face = tired ? .tired : .chill
            case .rest:
                if let t = dozeTime {
                    pose = .doze
                    face = HakuNode.dozeNod(t) < 0.5 ? .idle : .closed
                } else {
                    face = .closed
                }
            case .box, .shadowbox: face = .box
            case .bench: face = .focus
            case .idle:
                // Now and then he stretches, or glances the other way.
                let cycle = clock.truncatingRemainder(dividingBy: 16)
                if !tired, cycle > 12, cycle < 13.6 {
                    pose = .stretch
                    face = .yawn
                } else if cycle > 7, cycle < 8.3 {
                    facing.toggle()
                }
            default: break
            }
        }
        if let one = oneOff {
            if clock < one.until {
                if let p = one.pose, pose == .stand || pose == .tired || pose == .stretch { pose = p }
                face = one.face
            } else {
                oneOff = nil
            }
        }
        if face.blinks, clock.truncatingRemainder(dividingBy: 3.7) < 0.13 { face = .closed }

        if let node = haku as? HakuNode { node.dress(model.outfit) }
        haku.apply(
            pose, face: face, facingRight: facing,
            gloves: model.mode == .boxing && model.card == .boxing, t: dozeTime ?? clock)

        var position = HomeGrid.scene(HomeGrid.plan(point))
        if let hop = hopStart {
            let f = (clock - hop) / 0.32
            if f < 1 { position.y += 10 * CGFloat(sin(.pi * f)) } else { hopStart = nil }
        }
        if let shake = shakeStart {
            let f = clock - shake
            if f < 0.45 { position.x += 3 * CGFloat(sin(f * 70)) } else { shakeStart = nil }
        }
        if let drag = dragPoint {
            position = CGPoint(x: drag.x, y: drag.y - 64)
            depth = 40
        }
        haku.position = position
        haku.zPosition = CGFloat(depth)

        // The bar rests on the rack, or rides in HAKU's hands while he presses.
        if let barbell {
            let pressing = pose == .press
            barbell.position = pressing ? haku.barCenter : Self.rackedBar
            // While pressing, over his body and under his arms and head (`HakuNode` parts sit 0.004 to 0.006 up).
            barbell.zPosition = CGFloat(pressing ? depth + 0.0045 : HomeItem.bench.depth + 0.01)
        }

        // The bag swings after each punch.
        if pose == .box, reached == .box {
            let phase = clock.truncatingRemainder(dividingBy: 0.9) / 0.9
            if lastPunchPhase < 0.45, phase >= 0.45 { bagHit = clock }
            lastPunchPhase = phase
        }
        if let bag = itemNodes[.bag] {
            let since = bagHit.map { clock - $0 } ?? 99
            bag.zRotation = since < 1.5 ? CGFloat(-0.09 * exp(-since * 3) * cos(since * 12)) : 0
        }
        drawBlanket(covering: reached == .rest && walk == nil && pose != .doze)
        lightFace(pose == .doze)
    }

    // Mike 2026-10-15 approved dozing over the phone tucked in bed before sleep; 2026-10-17 he asked to see him
    // asleep under the blanket again. So the doze is only the first nods after getting into bed at night, and it
    // ends as he nods off the third time.
    /// How long HAKU dozes over the phone after getting into bed at night, in seconds.
    nonisolated static let dozeLength: TimeInterval = 28.5

    /// Seconds since HAKU got into bed while he still dozes over the phone, `nil` otherwise.
    private var dozeTime: TimeInterval? {
        guard model.isNight, reached == .rest, walk == nil, let since = restSince else { return nil }
        let t = clock - since
        return t < Self.dozeLength ? t : nil
    }

    /// Lights HAKU's face with the phone's screen while he dozes over it, dimming as it sinks.
    private func lightFace(_ dozing: Bool) {
        if phoneGlow.parent == nil {
            phoneGlow.size = CGSize(width: 50, height: 50)
            phoneGlow.color = UIColorBridge.color(0xBFE4FF)
            phoneGlow.colorBlendFactor = 1
            phoneGlow.blendMode = .add
            phoneGlow.zPosition = 51
            addChild(phoneGlow)
        }
        phoneGlow.isHidden = !dozing
        guard dozing else { return }
        phoneGlow.position = haku.faceCenter
        // Faint, so his skin stays skin-coloured and his eyes don't wash into his hair.
        phoneGlow.alpha = 0.22 * CGFloat(1 - HakuNode.dozeNod(dozeTime ?? 0))
    }

    private func spawnEffects() {
        guard clock >= nextEffect else { return }
        if reached == .rest, walk == nil, dozeTime == nil {
            nextEffect = clock + 1.5
            float(HomeEffects.zzz, from: HomeGrid.plan(8.2, 5.7, 1.6), drift: CGVector(dx: 14, dy: 26))
        } else if reached == .sofa, walk == nil, model.items.contains(.speaker) {
            nextEffect = clock + 1.1
            let s = HomeItem.speaker.spot
            float(HomeEffects.note, from: HomeGrid.plan(s.x, s.y, 1.1), drift: CGVector(dx: -8, dy: 24))
        } else {
            nextEffect = clock + 0.5
        }
    }

    private func float(_ texture: SKTexture, from plan: CGPoint, drift: CGVector) {
        let sprite = SKSpriteNode(texture: texture)
        sprite.position = HomeGrid.scene(plan)
        sprite.zPosition = 55
        sprite.setScale(0.6)
        addChild(sprite)
        sprite.run(
            SKAction.sequence([
                SKAction.group([
                    SKAction.move(by: drift, duration: 1.6),
                    SKAction.scale(to: 1, duration: 1.6),
                    SKAction.sequence([SKAction.wait(forDuration: 0.9), SKAction.fadeOut(withDuration: 0.7)]),
                ]),
                SKAction.removeFromParent(),
            ]))
    }

    private func play(_ cue: HomeCue, animated: Bool) {
        switch cue {
        case .bounce:
            hopStart = clock
            oneOff = (.happy, .happy, clock + 0.7)
        case .annoyed:
            shakeStart = clock
            oneOff = (nil, .box, clock + 1.2)
        case .changed:
            break
        case .poof:
            oneOff = (.happy, .happy, clock + 0.9)
            guard animated else { return }
            let center = CGPoint(x: haku.position.x, y: haku.position.y + 40)
            for dx: CGFloat in [-14, 14, 0] {
                let puff = SKSpriteNode(texture: HomeEffects.puff)
                puff.position = CGPoint(x: center.x + dx, y: center.y + (dx == 0 ? 18 : 0))
                puff.zPosition = 45
                puff.setScale(0.4)
                addChild(puff)
                puff.run(
                    SKAction.sequence([
                        SKAction.group([SKAction.scale(to: 1.3, duration: 0.45), SKAction.fadeOut(withDuration: 0.45)]),
                        SKAction.removeFromParent(),
                    ]))
            }
        case .placed(let item):
            guard animated, let node = itemNodes[item] else { return }
            node.setScale(0.01)
            node.run(
                SKAction.sequence([
                    SKAction.scale(to: 1.15, duration: 0.22),
                    SKAction.scale(to: 0.95, duration: 0.1),
                    SKAction.scale(to: 1, duration: 0.08),
                ]))
            let base = node.position
            for i in 0..<7 {
                let a = Double(i) / 7 * 2 * .pi
                let star = SKSpriteNode(texture: HomeEffects.sparkle)
                star.position = CGPoint(x: base.x, y: base.y + 30)
                star.zPosition = 56
                addChild(star)
                let v = CGVector(dx: CGFloat(cos(a)) * 46, dy: CGFloat(sin(a)) * 40 + 10)
                star.run(
                    SKAction.sequence([
                        SKAction.group([SKAction.move(by: v, duration: 0.6), SKAction.fadeOut(withDuration: 0.6)]),
                        SKAction.removeFromParent(),
                    ]))
            }
        }
    }

    // MARK: Touch

    /// What sits under a scene point, the front-most first.
    /// - Parameters:
    ///   - p: The point in scene units.
    ///   - includingHaku: Whether HAKU himself counts.
    ///   - minSide: The smallest tap target in scene units. A miss still lands on the nearest target
    ///     narrower or shorter than this whose box, grown to this size around its centre, holds the point.
    func hotspot(at p: CGPoint, includingHaku: Bool = true, minSide: CGFloat = 0) -> HomeHotspot? {
        let targets = tapTargets(includingHaku: includingHaku)
        if let hit = targets.first(where: { HomeGrid.contains($0.outline, p) }) { return hit.hotspot }
        let grown = targets.compactMap { target -> (HomeHotspot, CGFloat)? in
            let box = Self.grown(target.outline, to: minSide)
            let small = Self.grown(target.outline, to: 0).size
            guard small.width < minSide || small.height < minSide, box.contains(p) else { return nil }
            return (target.hotspot, hypot(p.x - box.midX, p.y - box.midY))
        }
        return grown.min { $0.1 < $1.1 }?.0
    }

    /// Everything that answers a tap, front-most first, each outlined in scene units.
    func tapTargets(includingHaku: Bool = true) -> [(hotspot: HomeHotspot, outline: [CGPoint])] {
        func outline(_ box: GridBox) -> [CGPoint] { HomeGrid.silhouette(box).map(HomeGrid.scene) }
        var targets: [(hotspot: HomeHotspot, outline: [CGPoint])] = []
        if includingHaku {
            let r = haku.calculateAccumulatedFrame().insetBy(dx: 4, dy: 2)
            targets.append(
                (
                    .haku,
                    [
                        r.origin, CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY),
                        CGPoint(x: r.minX, y: r.maxY),
                    ]
                ))
        }
        if itemNodes[.bag] != nil {
            let s = HomeItem.bag.spot
            targets.append(
                (.bag, outline(GridBox(x0: s.x - 0.4, y0: s.y - 0.4, x1: s.x + 0.4, y1: s.y + 0.4, z1: 2.6))))
        }
        if itemNodes[.bench] != nil, let bench = HomeItem.bench.footprint {
            targets.append((.bench, outline(bench)))
        }
        let tappable = HomePiece.allCases.filter { $0.hotspot != nil }.sorted { $0.depth > $1.depth }
        for piece in tappable {
            guard let hotspot = piece.hotspot, piece != .blanket || shownCovering == true else { continue }
            targets += piece.boxes.map { (hotspot, outline($0)) }
        }
        targets.append((.window, HomeArt.windowQuad().map(HomeGrid.scene)))
        return targets
    }

    /// The outline's bounding box, grown around its centre to at least `side` each way.
    static func grown(_ outline: [CGPoint], to side: CGFloat) -> CGRect {
        let box = outline.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
        return box.insetBy(dx: -max(0, side - box.width) / 2, dy: -max(0, side - box.height) / 2)
    }

    /// Starts carrying HAKU when the touch lands on him.
    func beginDrag(at p: CGPoint) -> Bool {
        guard haku.calculateAccumulatedFrame().insetBy(dx: -6, dy: -6).contains(p) else { return false }
        dragPoint = p
        walk = nil
        model.lift()
        return true
    }

    func drag(to p: CGPoint) {
        dragPoint = p
    }

    /// Lets HAKU go: onto the furniture under his feet, or onto the floor.
    func endDrag(at p: CGPoint) {
        dragPoint = nil
        let feet = CGPoint(x: p.x, y: p.y - 64)
        let spot = hotspot(at: feet, includingHaku: false) ?? hotspot(at: p, includingHaku: false)
        let floor = HomeGrid.floor(at: HomeGrid.plan(scene: feet))
        point = GridPoint(x: min(max(floor.x, 0.3), 9.7), y: min(max(floor.y, 0.3), 9.7))
        reached = nil
        landsDirectly = true
        model.drop(on: spot, at: point)
        head(to: model.spot, drop: model.dropPoint)
        sync()
    }
}

/// Converts hex colours for SpriteKit on both platforms.
enum UIColorBridge {
    #if os(iOS)
    static func color(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    #else
    static func color(_ hex: UInt32) -> NSColor {
        NSColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    #endif
}
#endif
