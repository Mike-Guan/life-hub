import HubCore
import SwiftUI

/// One filled and/or stroked shape of a `RunnerPart`, in SVG units.
struct RunnerInk {
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

/// Text inside a part, such as the ¥¥ on the mask LED. `y` is the baseline.
struct RunnerText: Sendable {
    var string: String
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
}

/// Where each part of RUNNER sits and how it is posed right now. All lengths are SVG units.
struct RunnerPose {
    /// Head nod, applied to every head part around the neck.
    var headDy: CGFloat = 0
    /// 1 = eyes open, near 0 = closed.
    var blink: CGFloat = 1
    /// Eyes looking up (work tap: eye roll).
    var eyesDy: CGFloat = 0
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
    /// Energy below 30: heavier eyelids, eye bags, slower moves, sweat on boxing day.
    var tired = false

    static let tiredThreshold = 30.0

    /// Whether `energy` (0-100, nil when unknown) counts as tired.
    static func isTired(_ energy: Double?) -> Bool {
        guard let energy else { return false }
        return energy < tiredThreshold
    }

    /// The still pose, used for reduced motion and static renders.
    init(tired: Bool = false) {
        self.tired = tired
        if tired { blink = 0.75 }
    }

    /// Pose at `time` for `mode`. `react` runs 0 → 1 → 0 after a tap.
    init(mode: Mode, time: TimeInterval, tired: Bool, react: Double) {
        self.init(tired: tired)
        let t = time * (tired ? 0.6 : 1)
        let open: CGFloat = tired ? 0.75 : 1
        let r = CGFloat(react)
        blink = open * Self.blink(at: t)

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
                if pose.tired, mode == .boxing {
                    SweatDrop()
                        .offset(x: 0, y: pose.headDy * scale)
                }
            }
        }
        .aspectRatio(RunnerArt.bounds.width / RunnerArt.bounds.height, contentMode: .fit)
    }

    /// Visible parts in back-to-front order.
    static func parts(for mode: Mode, pose: RunnerPose) -> [RunnerPart] {
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
        return RunnerPart.allCases.filter { visible.contains($0) }
    }

    static let baseParts: Set<RunnerPart> = [
        .jacket, .stripeNeon, .hoodCollar, .hairBack, .earL, .earR, .faceBase, .hairFringe,
    ]
    private static let workParts: Set<RunnerPart> = [
        .eyesWork, .lidsWork, .eyebags, .browsWork, .maskUp, .panelLines, .headset, .cupL, .cupR, .mic,
    ]
    private static let chillParts: Set<RunnerPart> = [
        .eyesChill, .mouthSmile, .maskDown, .earringNeon, .earbud, .monsterCan,
    ]
    private static let boxingParts: Set<RunnerPart> = [
        .cateyeL, .cateyeR, .browsBox, .mouthFang, .maskDown, .earringNeon, .headband, .gloveL, .gloveR,
    ]
    private static let moneyParts: Set<RunnerPart> = [
        .eyesMoney, .maskUp, .panelLines, .ledYen, .earringNeon, .chainGold, .coin,
    ]

    @ViewBuilder private func layer(_ part: RunnerPart, scale: CGFloat) -> some View {
        let head = Self.headParts.contains(part) ? pose.headDy * scale : 0
        Group {
            switch part {
            case .eyesWork, .lidsWork, .cateyeL, .cateyeR, .eyesMoney:
                RunnerPartView(part: part)
                    .scaleEffect(x: 1, y: pose.blink, anchor: Self.unit(x: 60, y: 65))
                    .offset(y: pose.eyesDy * scale)
            case .ledLine:
                RunnerPartView(part: part).opacity(pose.ledOpacity)
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
            case .monsterCan:
                RunnerPartView(part: part)
                    .rotationEffect(.degrees(pose.canAngle), anchor: Self.unit(x: 102, y: 136))
                    .offset(x: pose.canOffset.width * scale, y: pose.canOffset.height * scale)
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
        .offset(y: head)
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
    ]

    private static func jacketColor(_ mode: Mode) -> Color {
        switch mode {
        case .work, .boxing: RunnerPalette.jacket
        case .chill: RunnerPalette.jacketChill
        case .money: RunnerPalette.jacketMoney
        }
    }

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
            for ink in RunnerArt.inks(part) {
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
    let mode: Mode
    let energy: Double?

    public init(mode: Mode, energy: Double? = nil) {
        self.mode = mode
        self.energy = energy
    }

    public var body: some View {
        RunnerFigure(mode: mode, pose: RunnerPose(tired: RunnerPose.isTired(energy)))
            .accessibilityLabel("RUNNER，\(mode.title)")
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
    }
    .padding()
}
