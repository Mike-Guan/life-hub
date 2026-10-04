import HubCore
import SwiftUI

/// One filled and/or stroked shape of a `RunnerPart`, in SVG units.
struct RunnerInk: Sendable {
    var path: Path
    var fill: Color?
    var stroke: Color?
    var lineWidth: CGFloat
    var cap: CGLineCap
    var join: CGLineJoin
    var dash: [CGFloat]
    var opacity: Double

    init(
        path: Path,
        fill: Color? = nil,
        stroke: Color? = nil,
        lineWidth: CGFloat = 1,
        cap: CGLineCap = .butt,
        join: CGLineJoin = .miter,
        dash: [CGFloat] = [],
        opacity: Double = 1
    ) {
        self.path = path
        self.fill = fill
        self.stroke = stroke
        self.lineWidth = lineWidth
        self.cap = cap
        self.join = join
        self.dash = dash
        self.opacity = opacity
    }
}

extension RunnerArt {
    /// The inks of `part`, built once instead of on every frame.
    static func cachedInks(_ part: RunnerPart) -> [RunnerInk] {
        inkCache[part] ?? []
    }

    private static let inkCache: [RunnerPart: [RunnerInk]] = Dictionary(
        uniqueKeysWithValues: RunnerPart.allCases.map { ($0, inks($0)) }
    )
}

/// Text inside a part, such as the ¥¥ on the mask LED. `y` is the baseline.
struct RunnerText: Sendable {
    var string: String
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
}

/// RUNNER's face for an energy value: low, mid or high.
enum EnergyFace: Sendable {
    /// Heavier eyelids, eye bags, slower moves, sweat on boxing day.
    case low
    case mid
    /// Bright eyes, sparkles by the head, quicker moves.
    case high

    static let lowBelow = 30.0
    static let highFrom = 70.0

    /// The face for `energy` (0-100). Unknown energy is `.mid`.
    init(energy: Double?) {
        guard let energy else {
            self = .mid
            return
        }
        if energy < Self.lowBelow {
            self = .low
        } else if energy >= Self.highFrom {
            self = .high
        } else {
            self = .mid
        }
    }

    /// How fast idle loops run compared with `.mid`.
    var speed: Double {
        switch self {
        case .low: 0.6
        case .mid: 1
        case .high: 1.25
        }
    }
}

/// Where each part of RUNNER sits and how it is posed right now. All lengths are SVG units.
struct RunnerPose {
    /// Head nod, applied to every head part around the neck.
    var headDy: CGFloat = 0
    /// 1 = eyes open, near 0 = closed.
    var blink: CGFloat = 1
    /// Eyes looking up (work tap: eye roll).
    var eyesDy: CGFloat = 0
    /// Eyes looking sideways; negative is toward the door on the left.
    var eyesDx: CGFloat = 0
    var ledOpacity: Double = 1
    /// Work tap: the LED shows dots instead of the line.
    var ledDots = false
    var yenDx: CGFloat = 0
    var canAngle: Double = 0
    var canOffset: CGSize = .zero
    var gloveL: CGSize = .zero
    var gloveR: CGSize = .zero
    var gloveRScale: CGFloat = 1
    /// Position of the shine sweeping over the gold chain, as a fraction of the figure width.
    var glint: CGFloat = -1
    var coinTurn: Double = 0
    var face = EnergyFace.mid
    /// What RUNNER acts out on top of the mode's outfit.
    var need: CompanionNeed?
    /// Brightness of the sparkles by the head on high energy, 0...1.
    var sparkle: Double = 1
    /// Progress of the celebration sparkle burst, 0..<1, or -1 when none is playing.
    var burst: CGFloat = -1
    /// The workout being celebrated, which picks the move: gloves up, a peace sign or a lift.
    var cheerKind: WorkoutSummary.Kind?
    /// Scroll position of the feed on the phone screen while couch scrolling, 0...1.
    var feed: CGFloat = 0
    /// Bedtime overlay: sleepy eyes, mask down, the mode's outfit stays.
    var bedtime = false
    /// 0 = headset on, 1 = taken off.
    var headsetOff: CGFloat = 0
    /// 0 = mouth closed, 1 = widest yawn.
    var yawn: CGFloat = 0
    /// 0 = normal height, 1 = stretched up.
    var stretch: CGFloat = 0
    /// 0 = head upright, 1 = resting on the pillow.
    var lie: CGFloat = 0
    /// Rise of the floating Z z z, 0...1, or -1 when hidden.
    var zzz: CGFloat = -1
    /// The gym bag: -1 = not shown, 0 = on the floor by the door, 1 = over the shoulder.
    var bagLift: CGFloat = -1
    /// Progress of the off-work animation, 0...1, or -1 when none is playing.
    var offWork: CGFloat = -1
    /// 0 = mask up, 1 = pulled down to the chin.
    var maskDrop: CGFloat = 0
    var canOpacity: Double = 1
    /// What HAKU does on its own at home, or nil.
    var life: IdleLife?
    /// Offset of the prop HAKU is holding in its own time (console, snack, cloth).
    var prop: CGSize = .zero
    /// Offset of the pencil while drawing.
    var pencil: CGSize = .zero
    /// 0 = prop in view, 1 = hidden because someone looked.
    var propHidden: CGFloat = 0

    var tired: Bool { face == .low }
    var offWorking: Bool { offWork >= 0 }

    /// The still pose, used for reduced motion and static renders.
    init(face: EnergyFace = .mid, need: CompanionNeed? = nil, life: IdleLife? = nil) {
        self.face = face
        self.need = need
        self.life = need == nil ? life : nil
        if tired { blink = 0.75 }
        if need == .boxingWarmup { eyesDx = -2 }
        if need == .couchScroll {
            // Slumped, eyes down on the phone.
            headDy = 3
            eyesDy = 1.5
        }
        switch self.life {
        case .nap:
            blink = 0.15
            lie = 0.6
            zzz = 0.35
        case .handheld, .drawing:
            // Eyes down on the screen or the page.
            headDy = 2
            eyesDy = 1.5
        default:
            break
        }
    }

    /// Pose at `time` for `mode`. `react` runs 0 → 1 → 0 after a tap.
    init(
        mode: Mode,
        time: TimeInterval,
        face: EnergyFace,
        need: CompanionNeed? = nil,
        life: IdleLife? = nil,
        react: Double
    ) {
        self.init(face: face, need: need, life: life)
        let t = time * face.speed
        let open: CGFloat = tired ? 0.75 : 1
        let r = CGFloat(react)
        blink = open * Self.blink(at: t)
        // Sparkles twinkle out of step with the blink, 1.6 s period.
        sparkle = 0.55 + 0.45 * sin(time * 2 * .pi / 1.6)

        switch mode {
        case .work:
            // Nod to the music every 0.5 s; LED breathes over 2.4 s; tap = eye roll + "•••".
            headDy = CGFloat(abs(sin(t * .pi / 0.5))) * 1.5
            let breath = 0.5 + 0.5 * sin(t * 2 * .pi / 2.4)
            ledOpacity = (0.6 + 0.4 * breath) * (tired ? 0.5 : 1)
            eyesDy = -2 * r
            ledDots = react > 0.05
        case .chill:
            // A sip every 8 s; tap = raise the can.
            let phase = t.truncatingRemainder(dividingBy: 8)
            let sip = CGFloat(phase > 6.8 ? sin((phase - 6.8) / 1.2 * .pi) : 0)
            canAngle = Double(-28 * sip - 22 * r + (tired ? 14 : 0))
            canOffset = CGSize(width: -6 * sip, height: -6 * sip - 10 * r + (tired ? 4 : 0))
        case .boxing:
            // Guard bounce every 0.6 s, gloves alternate; tap = right jab.
            let bounce = CGFloat(sin(t * 2 * .pi / 0.6)) * 3
            gloveL = CGSize(width: 0, height: bounce)
            gloveR = CGSize(width: -14 * r, height: -bounce - 10 * r)
            gloveRScale = 1 + 0.2 * r
        case .money:
            // ¥¥ drifts on the LED, a shine runs along the chain every 3 s; tap = coin flip.
            yenDx = CGFloat(sin(t * 2 * .pi / 4)) * 2
            let sweep = t.truncatingRemainder(dividingBy: 3) / 3
            glint = sweep < 0.6 ? 0.28 + CGFloat(sweep / 0.6) * 0.5 : -1
            coinTurn = 360 * react
        }
        if need == .boxingWarmup { warmUp(time: t, react: r) }
        if need == .couchScroll { scroll(time: t) }
        if let life = self.life { live(life, time: t, react: r) }
    }

    /// HAKU's own time. A tap catches it: it wakes, hides the snack, closes the sketchbook or
    /// drops the gloves.
    private mutating func live(_ life: IdleLife, time t: TimeInterval, react r: CGFloat) {
        switch life {
        case .nap:
            // Breathing in the sofa corner, Z z z every 3 s; a tap half wakes it.
            blink = 0.15 + 0.85 * r
            lie = 0.6 * (1 - r)
            headDy = 1.5 + CGFloat(sin(t * 2 * .pi / 4))
            zzz = r > 0.05 ? -1 : CGFloat(t.truncatingRemainder(dividingBy: 3) / 3)
        case .handheld:
            // Button mashing: the console jitters, eyes glued to it.
            headDy = 2
            eyesDy = 1.5
            prop = CGSize(
                width: CGFloat(sin(t * 2 * .pi / 0.3)) * 0.8,
                height: CGFloat(sin(t * 2 * .pi / 0.45)) * 0.6
            )
        case .snack:
            // A bite every 3 s; a tap whips the snack away and the eyes slide off.
            let bite = Self.bump(CGFloat(t.truncatingRemainder(dividingBy: 3)), from: 0, to: 0.7)
            prop = CGSize(width: -12 * bite, height: -8 * bite)
            propHidden = r
            eyesDx = -3 * r
        case .drawing:
            headDy = 2
            eyesDy = 1.5
            pencil = CGSize(width: CGFloat(sin(t * 7)) * 2, height: CGFloat(cos(t * 5)) * 1.5)
            propHidden = r
        case .practice:
            // Left and right jabs every 1.2 s; a tap drops the gloves and looks away.
            let phase = CGFloat(t.truncatingRemainder(dividingBy: 1.2))
            let left = Self.bump(phase, from: 0, to: 0.35)
            let right = Self.bump(phase, from: 0.6, to: 0.95)
            gloveL = CGSize(width: 10 * left, height: -12 * left + 30 * r)
            gloveR = CGSize(width: -10 * right, height: -12 * right + 30 * r)
            gloveRScale = 1 + 0.2 * right
            eyesDx = -3 * r
        case .tidying:
            // Wiping in small circles, 1.2 s a round, head following along.
            let a = t * 2 * .pi / 1.2
            prop = CGSize(width: CGFloat(cos(a)) * 8, height: CGFloat(sin(a)) * 5)
            headDy = CGFloat(sin(a)) * 1
        }
    }

    /// Couch scrolling with the gym bag in view, glancing at it every 5 s.
    mutating func peekAtBag(time t: TimeInterval) {
        bagLift = 0
        eyesDx = -4 * Self.bump(CGFloat(t.truncatingRemainder(dividingBy: 5)), from: 3.4, to: 5)
    }

    /// Slumped over the phone: a thumb flick every 2.5 s, slow blinks.
    private mutating func scroll(time t: TimeInterval) {
        headDy = 3
        eyesDy = 1.5
        blink = 0.85 * Self.blink(at: t * 0.6)
        feed = Self.ramp(CGFloat(t.truncatingRemainder(dividingBy: 2.5)), from: 0, to: 0.4)
    }

    /// Gloves up and bouncing whatever the mode; a look at the door every 4 s.
    private mutating func warmUp(time t: TimeInterval, react r: CGFloat) {
        let bounce = CGFloat(sin(t * 2 * .pi / 0.6)) * 3
        gloveL = CGSize(width: 0, height: bounce)
        gloveR = CGSize(width: -14 * r, height: -bounce - 10 * r)
        gloveRScale = 1 + 0.2 * r
        eyesDx = -3 * Self.bump(CGFloat(t.truncatingRemainder(dividingBy: 4)), from: 2.6, to: 4)
    }

    /// Bedtime pose at `time`.
    /// - Parameters:
    ///   - goodnight: progress of the good-night animation, 0...1.
    ///   - liesDown: whether the head comes to rest on the pillow at the end.
    static func bedtime(time: TimeInterval, goodnight: Double, liesDown: Bool) -> RunnerPose {
        var pose = RunnerPose()
        pose.bedtime = true
        let g = CGFloat(min(max(goodnight, 0), 1))
        // Take the headset off, stretch while yawning, then lean onto the pillow.
        pose.headsetOff = ramp(g, from: 0, to: 0.25)
        pose.stretch = bump(g, from: 0.25, to: 0.55)
        // After that, a yawn every 6 s and Z z z rising every 3 s.
        let phase = time.truncatingRemainder(dividingBy: 6)
        let loopYawn = g >= 1 && phase < 1.2 ? CGFloat(sin(phase / 1.2 * .pi)) : 0
        pose.yawn = max(bump(g, from: 0.3, to: 0.65), loopYawn)
        pose.lie = liesDown ? ramp(g, from: 0.65, to: 0.9) : 0
        pose.zzz = g >= 0.9 ? CGFloat(time.truncatingRemainder(dividingBy: 3) / 3) : -1
        // Slow, heavy blinks; eyes squeeze shut in a yawn.
        pose.blink = max(0.15, (1 - 0.7 * pose.yawn) * blink(at: time * 0.5))
        pose.headDy = 1.5 * (1 - pose.lie) + 1.5 * pose.yawn
        return pose
    }

    /// Plays the celebration for `kind` at `progress` (0..<1) on top of the current pose.
    mutating func celebrate(_ kind: WorkoutSummary.Kind?, progress: CGFloat) {
        burst = progress
        cheerKind = kind
        guard kind == .boxing else { return }
        // Acts cool, then the right glove pumps up twice anyway.
        let pump = abs(sin(progress * 2 * .pi))
        gloveL = CGSize(width: 0, height: -6 * pump)
        gloveR = CGSize(width: -6 * pump, height: -24 * pump)
        gloveRScale = 1
    }

    /// Off-work pose at `progress` (0...1): headset off, mask down, a big stretch, then open a Monster.
    static func offWork(time: TimeInterval, progress: Double, face: EnergyFace) -> RunnerPose {
        var pose = RunnerPose(face: face)
        let p = CGFloat(min(max(progress, 0), 1))
        pose.offWork = p
        pose.headsetOff = ramp(p, from: 0, to: 0.15)
        pose.maskDrop = ramp(p, from: 0.15, to: 0.3)
        pose.stretch = bump(p, from: 0.3, to: 0.6)
        pose.yawn = bump(p, from: 0.35, to: 0.55)
        // The can comes up from below, then one long sip.
        let canIn = ramp(p, from: 0.6, to: 0.75)
        let sip = bump(p, from: 0.8, to: 1)
        pose.canOpacity = Double(canIn)
        pose.canOffset = CGSize(width: -6 * sip, height: 30 * (1 - canIn) - 6 * sip)
        pose.canAngle = Double(-28 * sip)
        pose.blink = max(0.15, (1 - 0.7 * pose.yawn) * blink(at: time))
        pose.headDy = 1.5 * pose.yawn
        return pose
    }

    /// The still bedtime pose, used for portraits and reduced motion.
    static func bedtimeStill() -> RunnerPose {
        var pose = bedtime(time: 2, goodnight: 1, liesDown: false)
        pose.yawn = 0
        pose.blink = 1
        pose.headDy = 1.5
        pose.zzz = 0.35
        return pose
    }

    /// 0 before `from`, 1 after `to`, linear in between.
    private static func ramp(_ x: CGFloat, from a: CGFloat, to b: CGFloat) -> CGFloat {
        min(max((x - a) / (b - a), 0), 1)
    }

    /// A half sine from `from` to `to`, 0 elsewhere.
    private static func bump(_ x: CGFloat, from a: CGFloat, to b: CGFloat) -> CGFloat {
        guard x > a, x < b else { return 0 }
        return sin((x - a) / (b - a) * .pi)
    }

    /// A quick blink every 4.5 s.
    private static func blink(at t: TimeInterval) -> CGFloat {
        let phase = t.truncatingRemainder(dividingBy: 4.5)
        guard phase < 0.16 else { return 1 }
        return max(0.1, CGFloat(abs(phase - 0.08) / 0.08))
    }
}

// Vector parts let every piece move on its own. When `runner.riv` exists, Rive takes over and
// this stays as the static fallback.
/// RUNNER drawn from the named vector parts in `RunnerArt`.
struct RunnerFigure: View {
    var mode: Mode
    var pose = RunnerPose()

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / RunnerArt.bounds.width
            ZStack {
                ForEach(Self.parts(for: mode, pose: pose), id: \.self) { part in
                    layer(part, scale: scale)
                }
                if pose.tired, mode == .boxing, !pose.bedtime {
                    SweatDrop()
                        .offset(x: 0, y: pose.headDy * scale)
                }
            }
            .scaleEffect(x: 1 - 0.03 * pose.stretch, y: 1 + 0.06 * pose.stretch, anchor: .bottom)
        }
        .aspectRatio(RunnerArt.bounds.width / RunnerArt.bounds.height, contentMode: .fit)
    }

    /// Visible parts in back-to-front order.
    nonisolated static func parts(for mode: Mode, pose: RunnerPose) -> [RunnerPart] {
        if pose.offWorking { return offWorkParts(pose) }
        var visible = baseParts
        switch mode {
        case .work:
            visible.formUnion(workParts)
            if !pose.ledDots { visible.insert(.ledLine) }
        case .chill:
            visible.formUnion(chillParts)
        case .boxing:
            visible.formUnion(boxingParts)
        case .money:
            visible.formUnion(moneyParts)
        }
        if pose.tired, mode != .chill { visible.insert(.eyebags) }
        if pose.need == .couchScroll, !pose.bedtime {
            visible.subtract(couchHiddenParts)
            visible.formUnion(couchParts)
        }
        if pose.need == .boxingWarmup, !pose.bedtime {
            visible.formUnion(warmupParts)
            visible.remove(.monsterCan)
        }
        if pose.bagLift >= 0, !pose.bedtime { visible.insert(.gymBag) }
        if let life = pose.life, pose.need == nil, !pose.bedtime {
            let added = lifeParts(life)
            visible.remove(.monsterCan)
            if !added.isDisjoint(with: [.eyesSleepy, .eyesWork]) { visible.remove(.eyesChill) }
            visible.formUnion(added)
        }
        if pose.burst >= 0, !pose.bedtime, let kind = pose.cheerKind, let props = cheerParts[kind] {
            visible.remove(.monsterCan)
            visible.formUnion(props)
        }
        if pose.face == .high || pose.burst >= 0 {
            visible.insert(.sparkle)
            if mode != .chill, pose.need != .couchScroll { visible.insert(.eyeGlint) }
        }
        if pose.bedtime {
            visible.subtract(awakeFaceParts)
            visible.formUnion(sleepyParts)
            visible.subtract([.sparkle, .eyeGlint])
            if pose.headsetOff >= 1 { visible.subtract(headsetParts) }
            if pose.yawn > 0.05 { visible.insert(.mouthYawn) }
            if pose.lie > 0 { visible.insert(.pillow) }
            if pose.zzz >= 0 { visible.insert(.zzz) }
        }
        return RunnerPart.allCases.filter { visible.contains($0) }
    }

    /// Work look turning into the chill look as the off-work animation plays, whatever the mode.
    nonisolated private static func offWorkParts(_ pose: RunnerPose) -> [RunnerPart] {
        var visible = baseParts.union([.earringNeon])
        let relaxed = pose.offWork >= 0.6
        visible.formUnion(relaxed ? [.eyesChill, .mouthSmile, .monsterCan] : [.eyesWork, .lidsWork, .browsWork])
        if pose.headsetOff < 1 { visible.formUnion(headsetParts) }
        if pose.maskDrop < 1 { visible.formUnion([.maskUp, .panelLines, .ledLine]) }
        if pose.maskDrop > 0 { visible.insert(.maskDown) }
        if pose.yawn > 0.05 { visible.insert(.mouthYawn) }
        return RunnerPart.allCases.filter { visible.contains($0) }
    }

    nonisolated static let baseParts: Set<RunnerPart> = [
        .jacket, .stripeNeon, .hoodCollar, .hairBack, .earL, .earR, .faceBase, .hairFringe,
    ]
    nonisolated private static let workParts: Set<RunnerPart> = [
        .eyesWork, .lidsWork, .eyebags, .browsWork, .maskUp, .panelLines, .headset, .cupL, .cupR, .mic,
    ]
    nonisolated private static let chillParts: Set<RunnerPart> = [
        .eyesChill, .mouthSmile, .maskDown, .earringNeon, .earbud, .monsterCan,
    ]
    nonisolated private static let boxingParts: Set<RunnerPart> = [
        .cateyeL, .cateyeR, .browsBox, .mouthFang, .maskDown, .earringNeon, .headband, .gloveL, .gloveR,
    ]
    nonisolated private static let moneyParts: Set<RunnerPart> = [
        .eyesMoney, .maskUp, .panelLines, .ledYen, .earringNeon, .chainGold, .coin,
    ]
    nonisolated private static let awakeFaceParts: Set<RunnerPart> = [
        .eyesWork, .lidsWork, .browsWork, .eyesChill, .cateyeL, .cateyeR, .browsBox, .eyesMoney,
        .mouthSmile, .mouthFang, .maskUp, .panelLines, .ledLine, .ledYen,
    ]
    nonisolated private static let warmupParts: Set<RunnerPart> = [.headband, .gloveL, .gloveR]
    nonisolated private static let couchParts: Set<RunnerPart> = [.eyesSleepy, .phone, .phoneFeed, .phoneHand]
    nonisolated private static let couchHiddenParts: Set<RunnerPart> = [
        .eyesWork, .lidsWork, .browsWork, .eyesChill, .cateyeL, .cateyeR, .browsBox, .eyesMoney,
        .mouthSmile, .mouthFang, .monsterCan,
    ]
    nonisolated private static let sleepyParts: Set<RunnerPart> = [.eyesSleepy, .eyebags, .maskDown]
    nonisolated private static let headsetParts: Set<RunnerPart> = [.headset, .cupL, .cupR, .mic]
    nonisolated private static let cheerParts: [WorkoutSummary.Kind: Set<RunnerPart>] = [
        .boxing: [.gloveL, .gloveR],
        .running: [.peaceHand],
        .strength: [.dumbbell],
    ]
    nonisolated private static let deadpanEyes: Set<RunnerPart> = [.eyesWork, .lidsWork, .browsWork]

    nonisolated private static func lifeParts(_ life: IdleLife) -> Set<RunnerPart> {
        switch life {
        case .nap: [.pillow, .eyesSleepy, .zzz]
        case .handheld: deadpanEyes.union([.handheld])
        case .snack: [.onigiri]
        case .drawing: deadpanEyes.union([.sketchbook, .pencil])
        case .practice: [.gloveL, .gloveR]
        case .tidying: [.cloth]
        }
    }

    @ViewBuilder private func layer(_ part: RunnerPart, scale: CGFloat) -> some View {
        let isHead = Self.headParts.contains(part)
        Group {
            switch part {
            case .eyesWork, .lidsWork, .cateyeL, .cateyeR, .eyesMoney, .eyesSleepy, .eyeGlint:
                RunnerPartView(part: part)
                    .scaleEffect(x: 1, y: pose.blink, anchor: Self.unit(x: 60, y: 65))
                    .offset(x: pose.eyesDx * scale, y: pose.eyesDy * scale)
            case .eyesChill:
                // Closed smiling eyes don't blink, but they still look at the door while warming up.
                RunnerPartView(part: part).offset(x: pose.eyesDx * scale)
            case .maskUp where pose.offWorking, .panelLines where pose.offWorking, .ledLine where pose.offWorking:
                // Off work: the mask slides down to the chin.
                RunnerPartView(part: part)
                    .offset(y: 12 * pose.maskDrop * scale)
                    .opacity(Double(1 - pose.maskDrop))
            case .maskDown where pose.offWorking:
                RunnerPartView(part: part).opacity(Double(pose.maskDrop))
            case .ledLine:
                RunnerPartView(part: part).opacity(pose.ledOpacity)
            case .headset, .cupL, .cupR, .mic:
                RunnerPartView(part: part)
                    .offset(y: -24 * pose.headsetOff * scale)
                    .opacity(Double(1 - pose.headsetOff))
            case .mouthYawn:
                RunnerPartView(part: part)
                    .scaleEffect(x: 0.7 + 0.3 * pose.yawn, y: pose.yawn, anchor: Self.unit(x: 60, y: 85))
            case .zzz:
                RunnerPartView(part: part)
                    .offset(x: 4 * pose.zzz * scale, y: -8 * pose.zzz * scale)
                    .opacity(Double(sin(pose.zzz * .pi)))
            case .phoneFeed:
                // The feed jumps up one post on each thumb flick.
                RunnerPartView(part: part)
                    .offset(y: -5 * pose.feed * scale)
                    .opacity(Double(1 - 0.6 * pose.feed))
            case .sparkle where pose.burst >= 0:
                // Celebration: the sparkles fly out from the head and fade.
                RunnerPartView(part: part)
                    .scaleEffect(0.8 + 0.7 * pose.burst, anchor: Self.unit(x: 60, y: 40))
                    .opacity(Double(sin(pose.burst * .pi)))
            case .sparkle:
                RunnerPartView(part: part)
                    .scaleEffect(0.8 + 0.2 * pose.sparkle, anchor: Self.unit(x: 60, y: 27))
                    .opacity(pose.sparkle)
            case .ledYen:
                RunnerPartView(part: part)
                    .offset(x: pose.yenDx * scale)
                    .opacity(pose.tired ? 0.45 : 1)
            case .maskUp where pose.ledDots:
                ZStack {
                    RunnerPartView(part: part)
                    RunnerTextView(text: Self.dots)
                }
            case .jacket:
                RunnerPartView(part: part, fillOverride: Self.jacketColor(mode))
            case .gymBag:
                // Lifted from the floor by the door onto the left shoulder.
                RunnerPartView(part: part)
                    .rotationEffect(.degrees(-10 * Double(pose.bagLift)), anchor: Self.unit(x: 24, y: 122))
                    .offset(x: 6 * pose.bagLift * scale, y: -16 * pose.bagLift * scale)
            case .peaceHand:
                // A sneaky peace sign pops up by the cheek and wiggles.
                RunnerPartView(part: part)
                    .scaleEffect(min(1, max(pose.burst, 0) * 4), anchor: Self.unit(x: 96, y: 84))
                    .rotationEffect(.degrees(Double(sin(pose.burst * 6 * .pi)) * 8), anchor: Self.unit(x: 96, y: 84))
            case .dumbbell:
                // Two quick reps.
                RunnerPartView(part: part).offset(y: -12 * abs(sin(pose.burst * 2 * .pi)) * scale)
            case .handheld, .cloth:
                RunnerPartView(part: part).offset(x: pose.prop.width * scale, y: pose.prop.height * scale)
            case .onigiri:
                RunnerPartView(part: part)
                    .offset(x: pose.prop.width * scale, y: (pose.prop.height + 34 * pose.propHidden) * scale)
                    .opacity(Double(1 - pose.propHidden))
            case .sketchbook:
                RunnerPartView(part: part)
                    .offset(y: 34 * pose.propHidden * scale)
                    .opacity(Double(1 - pose.propHidden))
            case .pencil:
                RunnerPartView(part: part)
                    .offset(x: pose.pencil.width * scale, y: (pose.pencil.height + 34 * pose.propHidden) * scale)
                    .opacity(Double(1 - pose.propHidden))
            case .monsterCan:
                RunnerPartView(part: part)
                    .rotationEffect(.degrees(pose.canAngle), anchor: Self.unit(x: 102, y: 136))
                    .offset(x: pose.canOffset.width * scale, y: pose.canOffset.height * scale)
                    .opacity(pose.canOpacity)
            case .gloveL:
                RunnerPartView(part: part)
                    .offset(x: pose.gloveL.width * scale, y: pose.gloveL.height * scale)
            case .gloveR:
                RunnerPartView(part: part)
                    .scaleEffect(pose.gloveRScale, anchor: Self.unit(x: 86, y: 118))
                    .offset(x: pose.gloveR.width * scale, y: pose.gloveR.height * scale)
            case .chainGold:
                RunnerPartView(part: part)
                    .overlay {
                        if pose.glint >= 0 {
                            ChainGlint(position: pose.glint)
                                .mask { RunnerPartView(part: part) }
                        }
                    }
            case .coin:
                RunnerPartView(part: part)
                    .rotation3DEffect(
                        .degrees(pose.coinTurn),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: Self.unit(x: 60, y: 120)
                    )
            default:
                RunnerPartView(part: part)
            }
        }
        .offset(y: isHead ? pose.headDy * scale : 0)
        .rotationEffect(.degrees(isHead ? -14 * Double(pose.lie) : 0), anchor: Self.unit(x: 60, y: 96))
    }

    private static let dots = RunnerText(
        string: "•••",
        x: 60,
        y: 86,
        size: 9,
        color: RunnerPalette.neonCyan
    )

    /// Parts that move with the head.
    private static let headParts: Set<RunnerPart> = [
        .hairBack, .earL, .earR, .faceBase, .eyesWork, .lidsWork, .eyebags, .browsWork, .eyesChill,
        .cateyeL, .cateyeR, .browsBox, .eyesMoney, .mouthSmile, .mouthFang, .maskUp, .panelLines,
        .ledLine, .ledYen, .hairFringe, .earringNeon, .earbud, .headband, .headset, .cupL, .cupR, .mic,
        .eyesSleepy, .mouthYawn, .eyeGlint, .sparkle,
    ]

    private static func jacketColor(_ mode: Mode) -> Color {
        switch mode {
        case .work, .boxing: RunnerPalette.jacket
        case .chill: RunnerPalette.jacketChill
        case .money: RunnerPalette.jacketMoney
        }
    }

    /// The head with headset and Z z z, in SVG units.
    nonisolated static let headBox = CGRect(x: 4, y: -6, width: 112, height: 106)

    /// An SVG point as a unit point of the figure's frame.
    static func unit(x: CGFloat, y: CGFloat) -> UnitPoint {
        let b = RunnerArt.bounds
        return UnitPoint(x: (x - b.minX) / b.width, y: (y - b.minY) / b.height)
    }
}

/// Draws one part, scaled from SVG units to the view's width.
struct RunnerPartView: View {
    let part: RunnerPart
    var fillOverride: Color?

    var body: some View {
        Canvas { context, size in
            RunnerDrawing.enterFigureSpace(&context, size: size)
            for ink in RunnerArt.cachedInks(part) {
                var layer = context
                layer.opacity = ink.opacity
                if let fill = ink.fill {
                    layer.fill(ink.path, with: .color(fillOverride ?? fill))
                }
                if let stroke = ink.stroke {
                    let style = StrokeStyle(
                        lineWidth: ink.lineWidth,
                        lineCap: ink.cap,
                        lineJoin: ink.join,
                        dash: ink.dash
                    )
                    layer.stroke(ink.path, with: .color(stroke), style: style)
                }
            }
            if let text = RunnerArt.text(part) {
                RunnerDrawing.draw(text, in: context)
            }
        }
    }
}

/// Draws one `RunnerText` in figure space.
struct RunnerTextView: View {
    let text: RunnerText

    var body: some View {
        Canvas { context, size in
            RunnerDrawing.enterFigureSpace(&context, size: size)
            RunnerDrawing.draw(text, in: context)
        }
    }
}

/// Shared drawing helpers for the figure's canvases.
enum RunnerDrawing {
    /// Maps SVG units onto a canvas that spans the whole figure frame.
    static func enterFigureSpace(_ context: inout GraphicsContext, size: CGSize) {
        let bounds = RunnerArt.bounds
        let scale = size.width / bounds.width
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
    }

    static func draw(_ text: RunnerText, in context: GraphicsContext) {
        let resolved = context.resolve(
            Text(text.string)
                .font(.system(size: text.size, weight: .bold))
                .foregroundStyle(text.color)
        )
        // `y` is the baseline; the bottom of the text box sits about one descent below it.
        context.draw(resolved, at: CGPoint(x: text.x, y: text.y + text.size * 0.22), anchor: .bottom)
    }
}

/// A soft white band that sweeps across the gold chain.
private struct ChainGlint: View {
    let position: CGFloat

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    RunnerPalette.white.opacity(0),
                    RunnerPalette.white.opacity(0.9),
                    RunnerPalette.white.opacity(0),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.1)
            .offset(x: geo.size.width * position)
        }
    }
}

/// A drop of sweat by the temple, boxing day on low energy.
private struct SweatDrop: View {
    var body: some View {
        Canvas { context, size in
            RunnerDrawing.enterFigureSpace(&context, size: size)
            var drop = Path()
            drop.move(to: CGPoint(x: 92, y: 50))
            drop.addQuadCurve(to: CGPoint(x: 92, y: 62), control: CGPoint(x: 99, y: 58))
            drop.addQuadCurve(to: CGPoint(x: 92, y: 50), control: CGPoint(x: 85, y: 58))
            drop.closeSubpath()
            context.fill(drop, with: .color(RunnerPalette.neonCyan))
            context.stroke(drop, with: .color(RunnerPalette.ink), lineWidth: 2)
        }
    }
}

/// RUNNER standing still in `mode`, for widgets, snapshots and anywhere motion isn't wanted.
public struct CompanionPortrait: View {
    /// How much of RUNNER to show.
    public enum Framing: Sendable {
        /// Head to waist.
        case full
        /// Head only, for small round widgets.
        case head
    }

    let mode: Mode
    let energy: Double?
    let need: CompanionNeed?
    let needSince: Date?
    let date: Date
    let bedtime: Bedtime
    let framing: Framing

    // WidgetKit renders future entries ahead of time, so `.now` would show the wrong couch stage.
    /// - Parameters:
    ///   - needSince: when `need` started; after 30 minutes of couch scrolling HAKU eyes the gym bag.
    ///   - date: the moment shown, such as a widget timeline entry's date.
    public init(
        mode: Mode,
        energy: Double? = nil,
        need: CompanionNeed? = nil,
        needSince: Date? = nil,
        date: Date = .now,
        bedtime: Bedtime = .off,
        framing: Framing = .full
    ) {
        self.mode = mode
        self.energy = energy
        self.need = need
        self.needSince = needSince
        self.date = date
        self.bedtime = bedtime
        self.framing = framing
    }

    public var body: some View {
        Group {
            switch framing {
            case .full:
                figure
            case .head:
                HeadCrop { figure }
            }
        }
        .accessibilityLabel(
            CompanionLines.accessibilityLabel(mode: mode, need: need, peeking: peeking, bedtime: bedtime)
        )
    }

    private var peeking: Bool {
        need == .couchScroll && CouchStage.at(date, since: needSince, inviting: false) == .peeking
    }

    private var figure: RunnerFigure {
        guard bedtime == .off else { return RunnerFigure(mode: mode, pose: RunnerPose.bedtimeStill()) }
        var pose = RunnerPose(face: EnergyFace(energy: energy), need: need)
        if peeking {
            pose.bagLift = 0
            pose.eyesDx = -3
        }
        return RunnerFigure(mode: mode, pose: pose)
    }
}

/// Shows only `RunnerFigure.headBox` of the figure.
private struct HeadCrop<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        let bounds = RunnerArt.bounds
        let head = RunnerFigure.headBox
        GeometryReader { geo in
            let scale = geo.size.width / head.width
            content
                .frame(width: bounds.width * scale, height: bounds.height * scale)
                .offset(x: (bounds.minX - head.minX) * scale, y: (bounds.minY - head.minY) * scale)
        }
        .aspectRatio(head.width / head.height, contentMode: .fit)
        .clipped()
    }
}

#Preview("Parts") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))]) {
        ForEach(Mode.allCases) { mode in
            CompanionPortrait(mode: mode)
                .padding(8)
                .background(mode.color)
        }
        CompanionPortrait(mode: .boxing, energy: 10)
            .padding(8)
            .background(Mode.boxing.color)
        CompanionPortrait(mode: .work, energy: 85)
            .padding(8)
            .background(Mode.work.color)
        CompanionPortrait(mode: .work, bedtime: .on)
            .padding(8)
            .background(Mode.work.color)
        CompanionPortrait(mode: .chill, need: .boxingWarmup)
            .padding(8)
            .background(Mode.chill.color)
        CompanionPortrait(mode: .chill, need: .boxingWarmup, framing: .head)
            .frame(width: 76)
            .background(Mode.chill.color, in: Circle())
        CompanionPortrait(mode: .work, bedtime: .on, framing: .head)
            .frame(width: 76)
            .background(.black, in: Circle())
        ForEach(IdleLife.allCases, id: \.self) { life in
            RunnerFigure(mode: .chill, pose: RunnerPose(life: life))
                .padding(8)
                .background(Mode.chill.color)
        }
    }
    .padding()
}
