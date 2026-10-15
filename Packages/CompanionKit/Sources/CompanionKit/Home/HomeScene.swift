#if os(iOS) || os(macOS)
import SpriteKit
import SwiftUI

/// The isometric room with HAKU in it. SpriteKit draws and moves; `HomeModel` decides.
@MainActor
final class HomeScene: SKScene {
    let model: HomeModel
    let haku = HakuNode()

    private var pieces: [HomePiece: SKSpriteNode] = [:]
    private var itemNodes: [HomeItem: SKSpriteNode] = [:]
    private let shell = SKSpriteNode()
    private let skyDay = SKSpriteNode()
    private let skyNight = SKSpriteNode()
    private let windowFrame = SKSpriteNode()
    private let screen = SKSpriteNode()
    private let sun = SKSpriteNode()
    private let shade = SKSpriteNode()
    private var nightLights: [SKSpriteNode] = []
    private var monitorLight = SKSpriteNode()
    private let daylight = SKSpriteNode()

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
    private var lastTime: TimeInterval?
    private var oneOff: (pose: HakuPose?, face: HakuFace, until: TimeInterval)?
    private var hopStart: TimeInterval?
    private var shakeStart: TimeInterval?
    private var bagHit: TimeInterval?
    private var lastPunchPhase = 0.0
    private var nextEffect: TimeInterval = 0

    // What the drawing shows now, to redraw only what changed.
    private var shownColors: [HomePaintable: UInt32] = [:]
    private var shownOutfits: [HomeOutfit] = []
    private var shownNight: Bool?
    private var shownScreen: HomeScreen?
    private var shownCovering: Bool?

    static let walkSpeed = 2.6

    /// The spot HAKU has reached, or `nil` while walking, carried or dropped on the floor.
    var spotReached: HomeSpot? { reached }
    var isWalking: Bool { walk != nil }

    init(model: HomeModel) {
        self.model = model
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
        shell.zPosition = -10
        addChild(shell)
        for sprite in [skyDay, skyNight] {
            sprite.zPosition = -9.5
            addChild(sprite)
        }
        let windowRect = HomeGrid.bounds([GridBox(x0: 1.7, y0: 0, x1: 5.5, y1: 0.35, z0: 1.5, z1: 5.4)])
        place(skyDay, windowRect, HomeTextures.texture(windowRect) { HomeArt.sky(IsoPen(context: $0), night: false) })
        place(skyNight, windowRect, HomeTextures.texture(windowRect) { HomeArt.sky(IsoPen(context: $0), night: true) })
        place(windowFrame, windowRect, HomeTextures.texture(windowRect) { HomeArt.windowFrame(IsoPen(context: $0)) })
        windowFrame.zPosition = -9
        addChild(windowFrame)

        let floorRect = HomeGrid.bounds([GridBox(x0: 0, y0: 0, x1: HomeGrid.size, y1: HomeGrid.size, z1: 0)])
        place(sun, floorRect, HomeTextures.texture(floorRect) { HomeArt.sunPatch(IsoPen(context: $0)) })
        sun.zPosition = -0.9
        addChild(sun)

        for piece in HomePiece.allCases {
            let sprite = SKSpriteNode()
            sprite.zPosition = CGFloat(piece.depth)
            pieces[piece] = sprite
            addChild(sprite)
        }
        drawStaticPieces()

        let screenRect = HomeGrid.bounds([GridBox(x0: 0.3, y0: 1.2, x1: 0.36, y1: 2.8, z0: 1.65, z1: 2.52)], margin: 3)
        screen.zPosition = 2.65
        place(
            screen, screenRect, HomeTextures.texture(screenRect) { HomeArt.screen(IsoPen(context: $0), content: .off) })
        addChild(screen)

        let roomRect = HomeGrid.canvas
        place(shade, roomRect, HomeTextures.texture(roomRect) { HomeArt.nightShade(IsoPen(context: $0)) })
        shade.zPosition = 50
        addChild(shade)
        let lights: [(GridPoint, UInt32, CGFloat)] = [
            (GridPoint(x: 0.66, y: 1.0, z: 2.0), 0xFFC66B, 170),
            (GridPoint(x: 0.5, y: 8.4, z: 2.0), 0xFF5A7A, 190),
            (GridPoint(x: 9.45, y: 4.05, z: 1.4), 0xFFC66B, 160),
            (GridPoint(x: 9.5, y: 1.4, z: 2.4), 0x7CFF4F, 120),
            (GridPoint(x: 3.6, y: 0.4, z: 3.4), 0x9AA8FF, 170),
        ]
        for (at, hex, size) in lights {
            nightLights.append(glow(at, hex, size))
        }
        monitorLight = glow(GridPoint(x: 0.6, y: 2.0, z: 2.1), 0x3EF0FF, 120)
        daylight.texture = HomeEffects.glow
        daylight.size = CGSize(width: 300, height: 300)
        daylight.position = HomeGrid.scene(HomeGrid.plan(3.6, 1.0, 2.6))
        daylight.color = UIColorBridge.color(0xFFF1C2)
        daylight.colorBlendFactor = 1
        daylight.blendMode = .add
        daylight.alpha = 0.35
        daylight.zPosition = 51
        addChild(daylight)

        addChild(haku)
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

    private func drawStaticPieces() {
        let fixed: [HomePiece] = [
            .desk, .chairSeat, .chairBack, .shelf, .posters, .table, .shop, .bed, .nightstand, .floorLamp,
            .windowPlant, .doormat,
        ]
        for piece in fixed {
            draw(piece) { pen in
                switch piece {
                case .desk: HomeArt.desk(pen)
                case .chairSeat: HomeArt.chairSeat(pen)
                case .chairBack: HomeArt.chairBack(pen)
                case .shelf: HomeArt.shelf(pen)
                case .posters: HomeArt.posters(pen)
                case .table: HomeArt.table(pen)
                case .shop: HomeArt.shop(pen)
                case .bed: HomeArt.bed(pen)
                case .nightstand: HomeArt.nightstand(pen)
                case .floorLamp: HomeArt.floorLamp(pen)
                case .windowPlant: HomeArt.plant(pen, at: 5.7, 0.8, size: 1.0, pot: 0xFF8FC8)
                case .doormat: HomeArt.doormat(pen)
                default: break
                }
            }
        }
    }

    private func draw(_ piece: HomePiece, _ art: @escaping (IsoPen) -> Void) {
        guard let sprite = pieces[piece] else { return }
        let rect = HomeGrid.bounds(piece.boxes, margin: piece == .windowPlant ? 30 : 10)
        place(sprite, rect, HomeTextures.texture(rect) { art(IsoPen(context: $0)) })
    }

    // MARK: Syncing with the model

    /// Brings the drawing up to date with the model.
    func sync(animated: Bool = true) {
        let colors = Dictionary(uniqueKeysWithValues: HomePaintable.allCases.map { ($0, model.color($0)) })
        if colors != shownColors {
            redraw(colors)
            shownColors = colors
        }
        let outfits = HomeOutfit.allCases.filter { model.ownedOutfits.contains($0) }
        if outfits != shownOutfits {
            shownOutfits = outfits
            draw(.wardrobe) { HomeArt.wardrobe($0, owned: outfits) }
        }
        for item in model.items where itemNodes[item] == nil {
            addItem(item)
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

    private func redraw(_ colors: [HomePaintable: UInt32]) {
        let walls = colors[.walls] ?? HomePaintable.walls.swatches[0]
        let sofa = colors[.sofa] ?? HomePaintable.sofa.swatches[0]
        let rug = colors[.rug] ?? HomePaintable.rug.swatches[0]
        if colors[.walls] != shownColors[.walls] {
            let rect = HomeGrid.canvas
            place(shell, rect, HomeTextures.texture(rect) { HomeArt.shell(IsoPen(context: $0), walls: walls) })
            draw(.partition) { HomeArt.partition($0, walls: walls) }
        }
        if colors[.sofa] != shownColors[.sofa] {
            draw(.sofaBack) { HomeArt.sofaBack($0, sofa) }
            draw(.sofaFarArm) { HomeArt.sofaArm($0, sofa, near: false) }
            draw(.sofaSeat) { HomeArt.sofaSeat($0, sofa) }
            draw(.sofaNearArm) { HomeArt.sofaArm($0, sofa, near: true) }
        }
        if colors[.rug] != shownColors[.rug] {
            draw(.rug) { HomeArt.rug($0, rug) }
        }
        if colors[.bed] != shownColors[.bed] { shownCovering = nil }
        if !shownColors.isEmpty { flash() }
    }

    private func drawBlanket(covering: Bool) {
        guard covering != shownCovering else { return }
        shownCovering = covering
        let color = model.color(.bed)
        draw(.blanket) { HomeArt.blanket($0, color, covering: covering) }
    }

    private func addItem(_ item: HomeItem) {
        let sprite = SKSpriteNode()
        let s = item.spot
        let box = GridBox(x0: s.x - 0.5, y0: s.y - 0.5, x1: s.x + 0.5, y1: s.y + 0.5, z0: s.z, z1: s.z + 2.8)
        let rect = HomeGrid.bounds([box], margin: item == .plant ? 30 : 8)
        place(
            sprite, rect, HomeTextures.texture(rect) { HomeArt.item(IsoPen(context: $0), item) },
            pin: HomeGrid.plan(s))
        sprite.zPosition = CGFloat(item.depth)
        itemNodes[item] = sprite
        addChild(sprite)
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
        fade(shade, night ? 1 : 0)
        fade(sun, night ? 0 : 1)
        fade(daylight, night ? 0 : 0.35)
        for light in nightLights { fade(light, night ? 0.85 : 0) }
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
        let rect = HomeGrid.bounds([GridBox(x0: 0.3, y0: 1.2, x1: 0.36, y1: 2.8, z0: 1.65, z1: 2.52)], margin: 3)
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
        let tired = model.energy < 35
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
            case .rest: face = .closed
            case .box, .shadowbox: face = .box
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

        haku.apply(
            pose, face: face, outfit: model.outfit, facingRight: facing,
            gloves: model.mode == .boxing && model.card == .boxing, t: clock)

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
        drawBlanket(covering: reached == .rest && walk == nil)
    }

    private func spawnEffects() {
        guard clock >= nextEffect else { return }
        if reached == .rest, walk == nil {
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
    func hotspot(at p: CGPoint, includingHaku: Bool = true) -> HomeHotspot? {
        if includingHaku, haku.calculateAccumulatedFrame().insetBy(dx: 4, dy: 2).contains(p) { return .haku }
        let plan = HomeGrid.plan(scene: p)
        if itemNodes[.bag] != nil {
            let s = HomeItem.bag.spot
            let bag = GridBox(x0: s.x - 0.4, y0: s.y - 0.4, x1: s.x + 0.4, y1: s.y + 0.4, z1: 2.6)
            if HomeGrid.contains(HomeGrid.silhouette(bag), plan) { return .bag }
        }
        let tappable = HomePiece.allCases.filter { $0.hotspot != nil }.sorted { $0.depth > $1.depth }
        for piece in tappable where piece.boxes.contains(where: { HomeGrid.contains(HomeGrid.silhouette($0), plan) }) {
            if piece == .blanket, shownCovering != true { continue }
            return piece.hotspot
        }
        if HomeGrid.contains(HomeArt.windowQuad(), plan) { return .window }
        return nil
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
