#if os(iOS) || os(macOS)
import SwiftUI

// Issue #485. Mike 2026-10-16 picked the code-drawn room of the first prototype, refined (direction A): the
// same ink lines a little thinner, more small detail, soft contact shadows and a highlight on top edges.

/// A colour `k` of the way to white (k > 0) or to black (k < 0).
func tone(_ hex: UInt32, _ k: Double) -> Color {
    func channel(_ c: UInt32) -> Double {
        let v = Double(c) / 255
        return k < 0 ? v * (1 + k) : v + (1 - v) * k
    }
    return Color(red: channel((hex >> 16) & 0xFF), green: channel((hex >> 8) & 0xFF), blue: channel(hex & 0xFF))
}

/// Draws room pieces in plan coordinates.
struct IsoPen {
    var context: GraphicsContext
    static let ink = Color(hex: 0x111111)
    /// How much thinner than the first prototype the ink lines are.
    static let weight: CGFloat = 0.85

    func polygon(_ points: [CGPoint], _ fill: Color, line: CGFloat = 2.2) {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        context.fill(path, with: .color(fill))
        if line > 0 {
            context.stroke(
                path, with: .color(Self.ink), style: StrokeStyle(lineWidth: line * Self.weight, lineJoin: .round))
        }
    }

    /// A line; ink lines get the room's line weight, coloured ones keep `width`.
    func line(_ points: [CGPoint], _ color: Color? = nil, width: CGFloat = 2) {
        var path = Path()
        path.addLines(points)
        context.stroke(
            path, with: .color(color ?? Self.ink),
            style: StrokeStyle(lineWidth: color == nil ? width * Self.weight : width, lineCap: .round, lineJoin: .round)
        )
    }

    /// The three visible faces of a box: front-left (y = y1), front-right (x = x1) and top, with a light top edge.
    func box(
        _ b: GridBox, _ hex: UInt32, top: Color? = nil, left: Color? = nil, right: Color? = nil, line: CGFloat = 2.2
    ) {
        let p = { (x: Double, y: Double, z: Double) in HomeGrid.plan(x, y, z) }
        polygon(
            [p(b.x0, b.y1, b.z0), p(b.x1, b.y1, b.z0), p(b.x1, b.y1, b.z1), p(b.x0, b.y1, b.z1)],
            left ?? Color(hex: hex), line: line)
        polygon(
            [p(b.x1, b.y0, b.z0), p(b.x1, b.y1, b.z0), p(b.x1, b.y1, b.z1), p(b.x1, b.y0, b.z1)],
            right ?? tone(hex, -0.22), line: line)
        polygon(
            [p(b.x0, b.y0, b.z1), p(b.x1, b.y0, b.z1), p(b.x1, b.y1, b.z1), p(b.x0, b.y1, b.z1)],
            top ?? tone(hex, 0.14), line: line)
        guard line > 0, b.x1 - b.x0 > 0.15, b.y1 - b.y0 > 0.15 else { return }
        let e = 0.05
        self.line(
            [p(b.x0 + 2 * e, b.y1 - e, b.z1), p(b.x1 - e, b.y1 - e, b.z1), p(b.x1 - e, b.y0 + 2 * e, b.z1)],
            Color.white.opacity(0.45), width: 1.1)
    }

    func box(
        _ x0: Double, _ y0: Double, _ z0: Double, _ x1: Double, _ y1: Double, _ z1: Double, _ hex: UInt32,
        top: Color? = nil, line: CGFloat = 2.2
    ) {
        box(GridBox(x0: x0, y0: y0, x1: x1, y1: y1, z0: z0, z1: z1), hex, top: top, line: line)
    }

    /// A flat floor rectangle.
    func floor(
        _ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ fill: Color, z: Double = 0, line: CGFloat = 2.2
    ) {
        let p = { (x: Double, y: Double, z: Double) in HomeGrid.plan(x, y, z) }
        polygon([p(x0, y0, z), p(x1, y0, z), p(x1, y1, z), p(x0, y1, z)], fill, line: line)
    }

    /// A rectangle on the back wall plane y = `y`, from x `u0` to `u1` and z `v0` to `v1`.
    func onBackWall(
        y: Double = 0, _ u0: Double, _ v0: Double, _ u1: Double, _ v1: Double, _ fill: Color, line: CGFloat = 2.2
    ) {
        let p = { (x: Double, y: Double, z: Double) in HomeGrid.plan(x, y, z) }
        polygon([p(u0, y, v0), p(u1, y, v0), p(u1, y, v1), p(u0, y, v1)], fill, line: line)
    }

    /// A rectangle on the left wall plane x = `x`, from y `u0` to `u1` and z `v0` to `v1`.
    func onLeftWall(
        x: Double = 0, _ u0: Double, _ v0: Double, _ u1: Double, _ v1: Double, _ fill: Color, line: CGFloat = 2.2
    ) {
        let p = { (x: Double, y: Double, z: Double) in HomeGrid.plan(x, y, z) }
        polygon([p(x, u0, v0), p(x, u1, v0), p(x, u1, v1), p(x, u0, v1)], fill, line: line)
    }

    func ellipse(at c: CGPoint, rx: CGFloat, ry: CGFloat, _ fill: Color, line: CGFloat = 2) {
        let path = Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: 2 * rx, height: 2 * ry))
        context.fill(path, with: .color(fill))
        if line > 0 { context.stroke(path, with: .color(Self.ink), lineWidth: line * Self.weight) }
    }

    /// An upright cylinder standing on the floor at `x`, `y`.
    func cylinder(_ x: Double, _ y: Double, r: Double, _ z0: Double, _ z1: Double, _ hex: UInt32, line: CGFloat = 2) {
        let bottom = HomeGrid.plan(x, y, z0)
        let top = HomeGrid.plan(x, y, z1)
        let rx = CGFloat(r) * HomeGrid.unit * 1.22
        let ry = rx * 0.5
        ellipse(at: bottom, rx: rx, ry: ry, tone(hex, -0.12), line: line)
        let side = Path(CGRect(x: top.x - rx, y: top.y, width: 2 * rx, height: bottom.y - top.y))
        context.fill(side, with: .color(tone(hex, -0.12)))
        self.line([CGPoint(x: top.x - rx, y: top.y), CGPoint(x: bottom.x - rx, y: bottom.y)], width: line)
        self.line([CGPoint(x: top.x + rx, y: top.y), CGPoint(x: bottom.x + rx, y: bottom.y)], width: line)
        ellipse(at: top, rx: rx, ry: ry, tone(hex, 0.12), line: line)
    }

    /// A circle standing in the plane x = `x`, round the axis at `y`, `z`; the bench's plates.
    func discAcross(x: Double, _ y: Double, _ z: Double, r: Double, _ fill: Color, line: CGFloat = 1.8) {
        let points = (0..<20).map { i in
            let a = Double(i) / 20 * 2 * .pi
            return HomeGrid.plan(x, y + r * cos(a), z + r * sin(a))
        }
        polygon(points, fill, line: line)
    }

    /// Fills a plane quad with a gradient.
    func shade(_ points: [CGPoint], _ shading: GraphicsContext.Shading) {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        context.fill(path, with: shading)
    }

    /// A blurred flat shape: contact shadows and soft shade in corners.
    func soft(_ points: [CGPoint], _ color: Color, blur: CGFloat) {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: blur))
            layer.fill(path, with: .color(color))
        }
    }

    /// The soft shadow under a footprint on the floor.
    func contact(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) {
        let e = 0.12
        let p = { (x: Double, y: Double) in HomeGrid.plan(x, y) }
        soft(
            [p(x0 - e, y0 - e), p(x1 + e, y0 - e), p(x1 + e, y1 + e), p(x0 - e, y1 + e)],
            Color(hex: 0x2A1608).opacity(0.28), blur: 3.5)
    }
}

/// The room's colours.
enum HomeColors {
    static let floor: UInt32 = 0xE2A365
    static let plank: UInt32 = 0xB97A3F
    static let wallTop = Color(hex: 0xFFF6E5)
    static let cut: UInt32 = 0xEADCC2
    static let wood: UInt32 = 0xC98B4F
    static let woodDark: UInt32 = 0x6B4430
    static let navy: UInt32 = 0x2D3250
    static let pink: UInt32 = 0xFF3EA5
    static let leaf: UInt32 = 0x58C25A
    /// What night lays over every piece.
    static let night = Color(hex: 0x141A3A).opacity(0.42)
}

/// The drawing of each room piece, in plan coordinates.
enum HomeArt {
    typealias P = HomeGrid

    // MARK: Shell

    /// Slab, floor, the two cut walls with the window, and the soft shadows under the furniture.
    static func shell(_ pen: IsoPen, walls: UInt32, night: Bool) {
        let n = HomeGrid.size
        let h = HomeGrid.wallHeight
        let w = HomeGrid.wallThickness
        pen.box(
            GridBox(x0: -w, y0: -w, x1: n, y1: n, z0: -HomeGrid.slab, z1: 0), HomeColors.cut,
            top: tone(HomeColors.cut, 0), left: tone(HomeColors.cut, -0.08), right: tone(HomeColors.cut, -0.24))
        floorBoards(pen)
        pen.shade(
            [P.plan(0, 0), P.plan(n, 0), P.plan(n, n), P.plan(0, n)],
            .radialGradient(
                Gradient(colors: [Color.white.opacity(0.18), .clear]),
                center: P.plan(4.5, 4.5), startRadius: 10, endRadius: 300))
        // Back wall (y = 0), then the left wall (x = 0) that overlaps its corner.
        pen.box(
            GridBox(x0: -w, y0: -w, x1: n, y1: 0, z1: h), walls, top: HomeColors.wallTop,
            left: Color(hex: walls), right: tone(HomeColors.cut, -0.1))
        pen.box(
            GridBox(x0: -w, y0: 0, x1: 0, y1: n, z1: h), walls, top: HomeColors.wallTop,
            left: tone(HomeColors.cut, -0.06), right: tone(walls, -0.07))
        // Light on the back wall, dimmer towards the corner.
        pen.shade(
            [P.plan(0, 0, 0), P.plan(n, 0, 0), P.plan(n, 0, h), P.plan(0, 0, h)],
            .linearGradient(
                Gradient(colors: [Color.black.opacity(0.06), .clear, Color.white.opacity(0.12)]),
                startPoint: P.plan(0, 0, 3), endPoint: P.plan(n, 0, 3)))
        // Soft shade where the walls meet the floor and in the corner.
        let corner = Color(hex: 0x3B2414)
        pen.soft(
            [P.plan(0, 0), P.plan(n, 0), P.plan(n, 0.5), P.plan(0.5, 0.5), P.plan(0.5, n), P.plan(0, n)],
            corner.opacity(0.22), blur: 5)
        pen.soft(
            [P.plan(0, 0, 0), P.plan(0, 0, h), P.plan(0, 0.6, h), P.plan(0, 0.6, 0)], corner.opacity(0.12), blur: 6)
        pen.soft(
            [P.plan(0, 0, 0), P.plan(0, 0, h), P.plan(0.6, 0, h), P.plan(0.6, 0, 0)], corner.opacity(0.1), blur: 6)
        pen.onBackWall(0, 0, n, 0.22, tone(walls, -0.18), line: 1.6)
        pen.onLeftWall(0, 0, n, 0.22, tone(walls, -0.24), line: 1.6)
        pen.line([P.plan(0, 0, 0), P.plan(0, 0, h)], tone(walls, -0.3), width: 1.6)
        // A light switch by the door and a socket under the desk.
        pen.onLeftWall(8.9, 2.5, 9.15, 2.85, Color(hex: 0xFFFBF2), line: 1.2)
        pen.onLeftWall(0.6, 0.45, 0.8, 0.62, Color(hex: 0xFFFBF2), line: 1)
        windowFrame(pen)
        if !night { sunPatch(pen) }
        // Contact shadows under the fixed furniture.
        for b in [
            (0.0, 0.4, 1.5, 3.4), (1.6, 1.4, 2.6, 2.3), (0, 4.4, 2.2, 7.6), (3.0, 5.1, 4.4, 6.3), (6.8, 0, 8.9, 1.3),
            (9.0, 0.1, 10, 1.2), (6.6, 4.8, 9.6, 8.8), (9.0, 3.6, 9.9, 4.5), (0.25, 8.15, 0.75, 8.65),
        ] {
            pen.contact(b.0, b.1, b.2, b.3)
        }
    }

    /// Boards along x with staggered joints, grain streaks and a few knots.
    private static func floorBoards(_ pen: IsoPen) {
        let n = HomeGrid.size
        pen.floor(0, 0, n, n, Color(hex: HomeColors.floor))
        let joint = tone(HomeColors.plank, 0.15)
        var y = 0.55
        var row = 0
        while y < n {
            pen.line([P.plan(0, y), P.plan(n, y)], joint, width: 1.4)
            var x = row.isMultiple(of: 2) ? 1.6 : 0.7
            while x < n {
                pen.line([P.plan(x, y - 0.55), P.plan(x, y)], joint, width: 1.2)
                x += 2.4
            }
            y += 0.55
            row += 1
        }
        // Fixed streaks so the floor looks the same on every launch.
        var seed: UInt64 = 4
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 33) / Double(1 << 31)
        }
        let grain = tone(HomeColors.plank, 0.32).opacity(0.7)
        y = 0
        while y < n - 0.1 {
            for _ in 0..<3 {
                let x0 = next() * (n - 1.2)
                let yy = y + 0.15 + next() * 0.25
                pen.line([P.plan(x0, yy), P.plan(x0 + 0.5 + next() * 0.8, yy)], grain, width: 0.8)
            }
            if next() < 0.35 {
                pen.ellipse(
                    at: P.plan(0.5 + next() * (n - 1), y + 0.27), rx: 2.2, ry: 1, tone(HomeColors.plank, 0.2), line: 0)
            }
            y += 0.55
        }
    }

    // MARK: Window

    /// The window hole in the back wall.
    static let window = (u0: 1.0, u1: 3.6, z0: 2.1, z1: 4.5)

    static func windowQuad() -> [CGPoint] {
        let w = window
        return [P.plan(w.u0, 0, w.z0), P.plan(w.u1, 0, w.z0), P.plan(w.u1, 0, w.z1), P.plan(w.u0, 0, w.z1)]
    }

    /// Cuts the glass out of the wall so the sky behind shows, then draws the frame, blind and sill.
    private static func windowFrame(_ pen: IsoPen) {
        let w = window
        var glass = Path()
        glass.addLines(windowQuad())
        glass.closeSubpath()
        var cut = pen.context
        cut.blendMode = .clear
        cut.fill(glass, with: .color(.black))
        pen.context.stroke(glass, with: .color(IsoPen.ink), lineWidth: 5 * IsoPen.weight)
        pen.context.stroke(glass, with: .color(Color(hex: 0xFFF6E5)), lineWidth: 2)
        let mid = (w.u0 + w.u1) / 2
        let bar = (w.z0 + w.z1) / 2
        pen.line([P.plan(mid, 0, w.z0), P.plan(mid, 0, w.z1)], width: 4)
        pen.line([P.plan(w.u0, 0, bar), P.plan(w.u1, 0, bar)], width: 4)
        // Reflections on the glass.
        pen.line(
            [P.plan(w.u0 + 0.2, 0, w.z1 - 0.25), P.plan(w.u0 + 0.55, 0, w.z1 - 0.7)], Color.white.opacity(0.18),
            width: 2.2)
        pen.line(
            [P.plan(mid + 0.25, 0, bar - 0.15), P.plan(mid + 0.65, 0, bar - 0.65)], Color.white.opacity(0.18),
            width: 2.2)
        // Rolled blind with its cord, and the sill.
        pen.box(w.u0 - 0.15, 0, w.z1 - 0.05, w.u1 + 0.15, 0.22, w.z1 + 0.3, HomeColors.navy)
        for u in stride(from: w.u0 + 0.15, to: w.u1, by: 0.45) {
            pen.line([P.plan(u, 0.22, w.z1 - 0.05), P.plan(u, 0.22, w.z1 + 0.3)], tone(HomeColors.navy, 0.2), width: 1)
        }
        pen.line(
            [P.plan(w.u1 - 0.1, 0.22, w.z1 - 0.05), P.plan(w.u1 - 0.1, 0.22, bar + 0.2)], tone(HomeColors.navy, 0.3),
            width: 1.2)
        pen.ellipse(at: P.plan(w.u1 - 0.1, 0.22, bar + 0.15), rx: 2, ry: 2.4, Color(hex: 0xFFF6E5), line: 1)
        pen.box(w.u0 - 0.2, 0, w.z0 - 0.12, w.u1 + 0.2, 0.32, w.z0, 0xF4E7D0)
    }

    /// Sunlight through the window onto the floor, with the bars' shadow.
    private static func sunPatch(_ pen: IsoPen) {
        let w = window
        pen.polygon(
            [
                P.plan(w.u0 + 0.2, 0.02, 0), P.plan(w.u1 - 0.2, 0.02, 0), P.plan(w.u1 + 1.6, 3.6, 0),
                P.plan(w.u0 + 1.8, 3.6, 0),
            ], Color(hex: 0xFFE9A8).opacity(0.5), line: 0)
        let m = (w.u0 + w.u1) / 2
        pen.soft(
            [P.plan(m - 0.06, 0.02), P.plan(m + 0.06, 0.02), P.plan(m + 1.76, 3.6), P.plan(m + 1.64, 3.6)],
            Color(hex: 0xC98B4F).opacity(0.35), blur: 1.2)
    }

    /// The sky and city behind the glass.
    static func sky(_ pen: IsoPen, night: Bool) {
        let w = window
        var c = pen.context
        var clip = Path()
        clip.addLines(windowQuad())
        clip.closeSubpath()
        c.clip(to: clip)
        let top = night ? Color(hex: 0x1C1F4A) : Color(hex: 0x8FCBFF)
        let bottom = night ? Color(hex: 0x4A3A7A) : Color(hex: 0xE2F3FF)
        c.fill(
            clip,
            with: .linearGradient(
                Gradient(colors: [top, bottom]),
                startPoint: P.plan(2.3, 0, w.z1), endPoint: P.plan(2.3, 0, w.z0)))
        let sub = IsoPen(context: c)
        if night {
            let moon = P.plan(3.0, 0, 4.0)
            c.fill(
                Path(ellipseIn: CGRect(x: moon.x - 23, y: moon.y - 23, width: 46, height: 46)),
                with: .radialGradient(
                    Gradient(colors: [Color(hex: 0xFFF3C4).opacity(0.45), .clear]), center: moon, startRadius: 0,
                    endRadius: 23))
            sub.ellipse(at: moon, rx: 9, ry: 9, Color(hex: 0xFFF3C4), line: 0)
            for (u, v) in [(1.3, 4.2), (1.8, 3.9), (2.3, 4.3), (2.6, 3.8), (3.4, 4.3), (1.2, 3.6)] {
                sub.ellipse(at: P.plan(u, 0, v), rx: 1.3, ry: 1.3, .white, line: 0)
            }
        } else {
            sub.ellipse(at: P.plan(3.1, 0, 4.1), rx: 13, ry: 7, Color.white.opacity(0.9), line: 0)
            sub.ellipse(at: P.plan(2.8, 0, 3.95), rx: 9, ry: 5, Color.white.opacity(0.9), line: 0)
            sub.ellipse(at: P.plan(1.5, 0, 4.25), rx: 10, ry: 5, Color.white.opacity(0.8), line: 0)
        }
        // City blocks: far row, then near row.
        let far: [(Double, Double, Double)] = [
            (0.9, 1.6, 3.6), (1.6, 2.1, 3.1), (2.1, 2.5, 4.0), (2.5, 3.1, 3.4),
            (3.1, 3.5, 3.9), (3.5, 4.0, 3.2), (4.0, 4.5, 3.7),
        ]
        let near: [(Double, Double, Double)] = [
            (0.9, 1.8, 2.7), (1.8, 2.2, 3.2), (2.2, 3.0, 2.6), (3.0, 3.4, 3.0),
            (3.4, 4.1, 2.5), (4.1, 4.5, 2.9),
        ]
        let farFill = night ? Color(hex: 0x2E2D63) : Color(hex: 0xB4CDE6)
        let nearFill = night ? Color(hex: 0x1F1E45) : Color(hex: 0x8EAFD0)
        for (u0, u1, v) in far { sub.onBackWall(u0, w.z0, u1, v, farFill, line: 0) }
        for (i, (u0, u1, v)) in near.enumerated() {
            sub.onBackWall(u0, w.z0, u1, v, nearFill, line: 0)
            guard night else { continue }
            // Lit windows.
            var u = u0 + 0.1
            var k = i
            while u + 0.1 < u1 {
                var z = w.z0 + 0.2
                while z + 0.15 < v {
                    k += 1
                    if k % 3 != 0 { sub.onBackWall(u, z, u + 0.09, z + 0.13, Color(hex: 0xFFD23F), line: 0) }
                    z += 0.3
                }
                u += 0.2
            }
        }
    }

    // MARK: Furniture

    /// Draws `piece` in its colour (sofa, rug and blanket take one).
    static func piece(_ pen: IsoPen, _ piece: HomePiece, color: UInt32, covering: Bool) {
        switch piece {
        case .desk: desk(pen)
        case .chairSeat: chairSeat(pen)
        case .chairBack: chairBack(pen)
        case .shelf: shelf(pen)
        case .posters: posters(pen)
        case .sofaBack: sofaBack(pen, color)
        case .sofaFarArm: sofaArm(pen, color, near: false)
        case .sofaSeat: sofaSeat(pen, color)
        case .sofaNearArm: sofaArm(pen, color, near: true)
        case .table: table(pen)
        case .rug: rug(pen, color)
        case .wardrobe: wardrobe(pen)
        case .shop: shop(pen)
        case .bed: bed(pen)
        case .blanket: blanket(pen, color, covering: covering)
        case .nightstand: nightstand(pen)
        case .floorLamp: floorLamp(pen)
        case .doormat: doormat(pen)
        }
    }

    private static func desk(_ pen: IsoPen) {
        let wood = HomeColors.wood
        for (x, y) in [(0.05, 0.5), (1.3, 0.5), (1.3, 2.3)] {
            pen.box(x, y, 0, x + 0.12, y + 0.12, 1.25, HomeColors.woodDark)
        }
        // Drawers with handles.
        pen.box(0.1, 2.4, 0, 1.4, 3.3, 1.25, wood)
        for z in [0.42, 0.84] {
            pen.line([P.plan(0.15, 3.3, z), P.plan(1.35, 3.3, z)], tone(wood, -0.4), width: 1.5)
            pen.line([P.plan(1.4, 2.45, z), P.plan(1.4, 3.25, z)], tone(wood, -0.4), width: 1.5)
        }
        for z in [0.21, 0.63, 1.05] {
            pen.line([P.plan(1.4, 2.75, z), P.plan(1.4, 2.95, z)], width: 3)
        }
        // Top with a notebook and pen.
        pen.box(0, 0.4, 1.25, 1.5, 3.4, 1.35, wood, top: tone(wood, 0.25))
        pen.box(0.85, 0.55, 1.35, 1.35, 1.15, 1.39, 0xFFFFFF, top: Color(hex: 0xFFFCF0), line: 1.4)
        pen.line([P.plan(0.95, 0.65, 1.39), P.plan(1.25, 1.05, 1.39)], Color(hex: HomeColors.pink), width: 1.2)
        // Monitor on its stand.
        pen.box(0.3, 1.85, 1.35, 0.6, 2.15, 1.4, 0x2A2C38)
        pen.box(0.38, 1.94, 1.4, 0.48, 2.06, 1.72, 0x2A2C38)
        pen.box(0.2, 1.15, 1.62, 0.32, 2.85, 2.55, 0x1E2030, top: Color(hex: 0x3A3D52))
        // Keyboard with its keys, and the mouse.
        pen.box(0.68, 1.45, 1.35, 0.98, 2.55, 1.4, 0xF2F2F2)
        for i in 1...5 {
            let y = 1.45 + Double(i) * 0.18
            pen.line([P.plan(0.7, y, 1.4), P.plan(0.96, y, 1.4)], tone(0xF2F2F2, -0.25), width: 0.7)
        }
        pen.box(0.8, 2.75, 1.35, 0.95, 2.88, 1.41, 0xF2F2F2)
        // Lamp: base, arm, shade.
        pen.box(0.25, 0.6, 1.35, 0.5, 0.85, 1.4, HomeColors.navy)
        pen.line([P.plan(0.37, 0.72, 1.4), P.plan(0.37, 0.72, 2.25), P.plan(0.62, 0.95, 2.4)], width: 2.5)
        pen.box(0.5, 0.85, 2.18, 0.82, 1.15, 2.42, 0x1B1C26)
        // Mug with a wisp of steam.
        pen.cylinder(1.15, 0.8, r: 0.1, 1.35, 1.6, 0xFFFFFF)
        pen.line(
            [P.plan(1.15, 0.8, 1.66), P.plan(1.12, 0.78, 1.8), P.plan(1.17, 0.8, 1.92)], Color.white.opacity(0.6),
            width: 1.2)
    }

    /// The plan rectangle the screen is drawn in.
    static let screenRect = HomeGrid.bounds(
        [GridBox(x0: 0.3, y0: 1.2, x1: 0.36, y1: 2.8, z0: 1.65, z1: 2.52)], margin: 3)

    /// The monitor's screen, facing HAKU's chair.
    static func screen(_ pen: IsoPen, content: HomeScreen) {
        let quad = [
            P.plan(0.33, 1.25, 1.7), P.plan(0.33, 2.75, 1.7), P.plan(0.33, 2.75, 2.48), P.plan(0.33, 1.25, 2.48),
        ]
        let base: UInt32 =
            switch content {
            case .off: 0x232636
            case .code: 0x103A44
            case .sketch: 0x3A2142
            }
        pen.polygon(quad, Color(hex: base), line: 1.8)
        switch content {
        case .off:
            pen.line([P.plan(0.33, 1.5, 2.3), P.plan(0.33, 1.9, 2.4)], Color.white.opacity(0.18), width: 3)
        case .code:
            for (i, z) in [2.33, 2.2, 2.07, 1.94, 1.81].enumerated() {
                let indent = [0, 0.15, 0.15, 0.3, 0][i]
                let len = [0.6, 0.8, 0.5, 0.7, 0.4][i]
                pen.line(
                    [P.plan(0.33, 1.4 + indent, z), P.plan(0.33, 1.4 + indent + len, z)],
                    i == 2 ? Color(hex: 0xFF3EA5) : Color(hex: 0x3EF0FF), width: 2.4)
            }
        case .sketch:
            pen.line(
                [P.plan(0.33, 1.45, 1.9), P.plan(0.33, 1.8, 2.25), P.plan(0.33, 2.1, 2.0), P.plan(0.33, 2.5, 2.35)],
                Color(hex: 0xFFD23F), width: 2.6)
            pen.ellipse(at: P.plan(0.33, 2.35, 1.85), rx: 5, ry: 4, Color(hex: 0xFF8FC8), line: 1.5)
        }
    }

    private static func chairSeat(_ pen: IsoPen) {
        for (dx, dy) in [(-0.45, 0.0), (0.45, 0.0), (0.0, -0.45), (0.0, 0.45)] {
            pen.line([P.plan(2.1, 1.85, 0.08), P.plan(2.1 + dx, 1.85 + dy, 0.05)], width: 3)
            pen.ellipse(at: P.plan(2.1 + dx, 1.85 + dy, 0.03), rx: 2.4, ry: 1.6, Color(hex: 0x1B1C26), line: 0)
        }
        pen.box(2.05, 1.8, 0.08, 2.15, 1.9, 0.6, 0x8A8FA8)
        pen.box(1.65, 1.35, 0.6, 2.55, 2.35, 0.74, HomeColors.navy)
    }

    private static func chairBack(_ pen: IsoPen) {
        pen.box(2.47, 1.8, 0.74, 2.55, 1.9, 0.95, 0x8A8FA8)
        pen.box(2.45, 1.4, 0.95, 2.62, 2.3, 1.75, HomeColors.navy)
        pen.line([P.plan(2.45, 1.55, 1.6), P.plan(2.45, 2.15, 1.6)], tone(HomeColors.navy, 0.25), width: 1)
    }

    /// Wall shelf on its brackets, with the keepsakes on it.
    private static func shelf(_ pen: IsoPen) {
        for z in [3.3, 4.5] {
            pen.box(0, 4.2, z, 0.6, 7.4, z + 0.12, HomeColors.wood)
            for y in [4.5, 7.1] {
                pen.onLeftWall(x: 0.02, y, z - 0.25, y + 0.08, z, Color(hex: HomeColors.woodDark), line: 1)
            }
        }
        // Lower board: trophy and can tower; the worn gloves stand between them once earned.
        pen.cylinder(0.3, 4.7, r: 0.12, 3.42, 3.55, 0xFFD23F)
        pen.box(0.22, 4.62, 3.55, 0.38, 4.78, 3.7, 0xFFD23F)
        pen.cylinder(0.3, 4.7, r: 0.18, 3.7, 4.0, 0xFFD23F)
        for (i, z) in [3.42, 3.66, 3.9].enumerated() {
            pen.cylinder(0.3, 6.75 - Double(i % 2) * 0.05, r: 0.1, z, z + 0.24, 0x1B1C26)
        }
        pen.line([P.plan(0.26, 6.84, 4.0), P.plan(0.34, 6.66, 3.62)], Color(hex: 0x7CFF4F), width: 1.6)
        // Upper board: running shoe, photo, books with titles.
        pen.box(0.15, 4.75, 4.62, 0.45, 5.35, 4.75, 0xFFFFFF)
        pen.box(0.15, 4.75, 4.75, 0.45, 4.98, 4.85, 0xFF3EA5)
        pen.box(0.05, 5.8, 4.62, 0.12, 6.4, 5.05, 0xFFF6E5)
        pen.onLeftWall(x: 0.12, 5.88, 4.7, 6.32, 4.97, Color(hex: 0x7FB2FF), line: 1.2)
        for (i, c) in [UInt32(0x3A6B58), 0xFF9F43, 0x2D3250].enumerated() {
            let y = 6.7 + Double(i) * 0.18
            let top = 5.0 - Double(i) * 0.06
            pen.box(0.08, y, 4.62, 0.5, y + 0.16, top, c)
            pen.line(
                [P.plan(0.5, y + 0.03, top - 0.1), P.plan(0.5, y + 0.13, top - 0.1)], Color.white.opacity(0.6), width: 1
            )
        }
    }

    /// The plan box the worn gloves fill on the shelf's lower board.
    static let wornGlovesBox = GridBox(x0: 0.1, y0: 5.3, x1: 0.5, y1: 6.1, z0: 3.42, z1: 4.05)

    /// A pair of taped, scuffed boxing gloves standing on their cuffs, thumbs out.
    static func wornGloves(_ pen: IsoPen) {
        for (y, side) in [(5.5, -1.0), (5.9, 1.0)] {
            let b = P.plan(0.3, y, 3.42)
            let s = CGFloat(side)
            let stroke = StrokeStyle(lineWidth: 1.6 * IsoPen.weight, lineJoin: .round)
            let red = Color(hex: 0xC23A44)
            let thumb = Path(ellipseIn: CGRect(x: b.x + s * 6 - 3.5, y: b.y - 16, width: 7, height: 9))
            let mitt = Path(roundedRect: CGRect(x: b.x - 7, y: b.y - 21, width: 14, height: 15), cornerRadius: 6)
            let cuff = Path(roundedRect: CGRect(x: b.x - 5.5, y: b.y - 7.5, width: 11, height: 7.5), cornerRadius: 1.5)
            for (path, fill) in [(thumb, red), (mitt, red), (cuff, Color(hex: 0xE9E1CF))] {
                pen.context.fill(path, with: .color(fill))
                pen.context.stroke(path, with: .color(IsoPen.ink), style: stroke)
            }
            // Tape turns on the cuff, and pale scuffs where the leather wore.
            pen.line(
                [CGPoint(x: b.x - 5.5, y: b.y - 5), CGPoint(x: b.x + 5.5, y: b.y - 3.5)], tone(0xE9E1CF, -0.3), width: 1
            )
            pen.line(
                [CGPoint(x: b.x - 4, y: b.y - 17), CGPoint(x: b.x - 1, y: b.y - 18)], tone(0xC23A44, 0.45), width: 1.2)
            pen.line(
                [CGPoint(x: b.x + 1, y: b.y - 12), CGPoint(x: b.x + 3.5, y: b.y - 11)], tone(0xC23A44, 0.45), width: 1)
        }
    }

    private static func posters(_ pen: IsoPen) {
        pen.onLeftWall(x: 0.02, 0.8, 2.9, 1.9, 4.5, Color(hex: 0x1B1C26), line: 2.2)
        pen.line(
            [P.plan(0.02, 1.05, 4.15), P.plan(0.02, 1.35, 3.3), P.plan(0.02, 1.65, 4.15)], Color(hex: 0xFF3EA5),
            width: 5)
        pen.onLeftWall(x: 0.02, 2.2, 3.1, 3.1, 4.4, Color(hex: 0xFFF6E5), line: 2.2)
        pen.line(
            [P.plan(0.02, 2.4, 3.6), P.plan(0.02, 2.6, 4.1), P.plan(0.02, 2.75, 3.5), P.plan(0.02, 2.9, 4.05)],
            Color(hex: 0x3A6B58), width: 3)
        // Pins.
        for (y, z) in [(1.35, 4.42), (2.65, 4.32)] {
            pen.ellipse(at: P.plan(0.02, y, z), rx: 1.6, ry: 1.6, Color(hex: 0xFF3B4E), line: 0.8)
        }
    }

    private static func sofaBack(_ pen: IsoPen, _ c: UInt32) {
        pen.box(0, 4.4, 0, 0.7, 7.6, 1.55, c, top: tone(c, 0.18))
        pen.line([P.plan(0.7, 6.0, 0.62), P.plan(0.7, 6.0, 1.5)], tone(c, -0.35), width: 1.4)
        // Back cushions with their buttons.
        pen.box(0.55, 4.95, 0.55, 0.85, 5.95, 1.35, 0xFF3EA5)
        pen.box(0.55, 6.05, 0.55, 0.85, 6.95, 1.3, 0x7CC77F)
        pen.ellipse(at: P.plan(0.85, 5.45, 0.95), rx: 2.2, ry: 1.6, tone(0xFF3EA5, -0.3), line: 0)
        pen.ellipse(at: P.plan(0.85, 6.5, 0.92), rx: 2.2, ry: 1.6, tone(0x7CC77F, -0.3), line: 0)
    }

    private static func sofaArm(_ pen: IsoPen, _ c: UInt32, near: Bool) {
        let y0 = near ? 7.0 : 4.4
        pen.box(0.7, y0, 0, 2.2, y0 + 0.6, 1.0, c, top: tone(c, 0.18))
    }

    private static func sofaSeat(_ pen: IsoPen, _ c: UInt32) {
        pen.box(0.7, 5.0, 0, 2.2, 7.0, 0.6, c, top: tone(c, 0.24))
        pen.line([P.plan(0.75, 6.0, 0.6), P.plan(2.2, 6.0, 0.6), P.plan(2.2, 6.0, 0.3)], tone(c, -0.35), width: 1.8)
        // Piping along the cushion fronts and a folded throw.
        pen.line([P.plan(2.2, 5.05, 0.5), P.plan(2.2, 6.95, 0.5)], tone(c, -0.2), width: 1)
        pen.box(0.9, 6.25, 0.6, 1.6, 6.9, 0.68, 0xEADCC2, top: Color(hex: 0xF4EAD6), line: 1.6)
        pen.line([P.plan(1.6, 6.3, 0.64), P.plan(1.6, 6.85, 0.64)], tone(0xEADCC2, -0.3), width: 1)
    }

    private static func table(_ pen: IsoPen) {
        for (x, y) in [(3.05, 5.15), (4.25, 5.15), (3.05, 6.15), (4.25, 6.15)] {
            pen.box(x, y, 0, x + 0.1, y + 0.1, 0.45, HomeColors.woodDark)
        }
        pen.box(3.0, 5.1, 0.45, 4.4, 6.3, 0.55, HomeColors.wood, top: tone(HomeColors.wood, 0.25))
        pen.box(3.25, 5.35, 0.55, 3.85, 5.8, 0.63, 0x3A6B58)
        pen.cylinder(4.05, 5.9, r: 0.1, 0.55, 0.8, 0x1B1C26)
        // A coaster with the remote on it.
        pen.box(3.4, 5.9, 0.55, 3.75, 6.2, 0.58, 0xFFFFFF, line: 1.2)
        pen.box(3.48, 5.97, 0.58, 3.67, 6.13, 0.61, 0x1B1C26, line: 1)
    }

    private static func rug(_ pen: IsoPen, _ c: UInt32) {
        pen.floor(2.6, 3.8, 6.0, 8.2, Color(hex: c), z: 0.01)
        pen.floor(2.85, 4.05, 5.75, 7.95, tone(c, 0.25), z: 0.01, line: 0)
        pen.floor(3.05, 4.25, 5.55, 7.75, Color(hex: c), z: 0.01, line: 0)
        // Fringe on the short ends.
        for i in 0..<18 {
            let x = 2.7 + Double(i) * 0.18
            pen.line([P.plan(x, 8.2, 0.01), P.plan(x, 8.36, 0.01)], tone(c, 0.35), width: 1.1)
            pen.line([P.plan(x, 3.8, 0.01), P.plan(x, 3.64, 0.01)], tone(c, 0.35), width: 1.1)
        }
    }

    /// The wardrobe with its open alcove; the clothes on the rail are drawn by `clothes`.
    private static func wardrobe(_ pen: IsoPen) {
        let wood: UInt32 = 0x8B5A3C
        pen.box(6.8, 0, 0, 8.9, 1.3, 4.6, wood)
        pen.onBackWall(y: 1.3, 7.0, 1.2, 8.7, 4.4, Color(hex: 0x3B2418))
        // Shoe shelf with a box and a pair of trainers.
        pen.box(7.0, 0.15, 1.2, 8.7, 1.3, 1.3, 0x9C6B4C)
        pen.box(7.1, 0.3, 1.3, 7.7, 1.1, 1.75, 0xEADCC2)
        for x in [7.9, 8.25] {
            pen.box(x, 0.4, 1.3, x + 0.3, 1.15, 1.45, 0xFFFFFF, line: 1.4)
            pen.line([P.plan(x, 1.15, 1.45), P.plan(x + 0.3, 1.15, 1.45)], Color(hex: HomeColors.pink), width: 1.2)
        }
        pen.onBackWall(y: 1.3, 6.85, 0.1, 8.85, 1.15, Color(hex: wood))
        pen.line([P.plan(7.6, 1.3, 0.65), P.plan(8.1, 1.3, 0.65)], width: 3)
        pen.line([P.plan(6.85, 1.3, 4.45), P.plan(8.85, 1.3, 4.45)], tone(wood, 0.2), width: 1.2)
        // Boxes on top, the red one tied with string.
        pen.box(7.0, 0.2, 4.6, 7.8, 1.0, 5.1, 0xFF3B4E)
        pen.line(
            [P.plan(7.0, 0.6, 5.1), P.plan(7.8, 0.6, 5.1), P.plan(7.8, 0.6, 4.6)], Color(hex: 0xFFF6E5), width: 1.4)
        pen.box(7.9, 0.25, 4.6, 8.6, 0.95, 4.95, 0x1B1C26)
    }

    /// The owned tops hanging on the rail in the wardrobe's alcove, with empty hangers after them.
    static func clothes(_ pen: IsoPen, owned: [HomeOutfit]) {
        let y = 1.32
        let steel = Color(hex: 0xC3C8D2)
        pen.line([P.plan(7.0, y, 4.05), P.plan(8.7, y, 4.05)], steel, width: 2.5)
        for i in 0..<5 {
            let u = 7.12 + Double(i) * 0.31
            let hook = u + 0.135
            if i < owned.count {
                pen.onBackWall(y: y, u, 2.5, u + 0.27, 3.95, owned[i].base, line: 1.6)
                pen.line([P.plan(hook, y, 3.95), P.plan(hook, y, 4.1)], width: 1.5)
            } else {
                pen.line(
                    [
                        P.plan(hook - 0.1, y, 3.9), P.plan(hook, y, 4.02), P.plan(hook + 0.1, y, 3.9),
                        P.plan(hook - 0.1, y, 3.9),
                    ], steel, width: 1.2)
            }
        }
    }

    private static func shop(_ pen: IsoPen) {
        pen.box(9.0, 0.1, 0, 10, 1.2, 3.6, 0x1B1C26, top: Color(hex: 0x2D3250))
        // Glass with cans, and a reflection.
        pen.onBackWall(y: 1.2, 9.1, 1.4, 9.72, 3.4, Color(hex: 0x0D3326), line: 2)
        for row in 0..<3 {
            for col in 0..<3 {
                let u = 9.16 + Double(col) * 0.19
                let z = 1.55 + Double(row) * 0.62
                pen.onBackWall(y: 1.2, u, z, u + 0.13, z + 0.42, Color(hex: 0x1B1C26), line: 1.2)
                pen.onBackWall(y: 1.2, u + 0.02, z + 0.12, u + 0.11, z + 0.3, Color(hex: 0x7CFF4F), line: 0)
            }
        }
        pen.line([P.plan(9.15, 1.2, 3.3), P.plan(9.4, 1.2, 2.9)], Color.white.opacity(0.22), width: 2)
        // Side panel with a bolt, coin slot, tray.
        pen.onBackWall(y: 1.2, 9.78, 1.4, 9.95, 3.4, Color(hex: 0x2D3250), line: 1.6)
        pen.line(
            [P.plan(9.9, 1.2, 2.85), P.plan(9.83, 1.2, 2.45), P.plan(9.9, 1.2, 2.45), P.plan(9.83, 1.2, 2.05)],
            Color(hex: 0x7CFF4F), width: 2.4)
        pen.onBackWall(y: 1.2, 9.2, 0.35, 9.8, 0.8, Color(hex: 0x0B0C12), line: 1.6)
        pen.line([P.plan(9.1, 1.2, 3.47), P.plan(9.95, 1.2, 3.47)], Color(hex: 0x3EF0FF), width: 2)
    }

    private static func bed(_ pen: IsoPen) {
        let frame: UInt32 = 0x5B3A29
        pen.box(6.6, 4.8, 0, 9.6, 5.05, 1.7, frame)
        for u in [7.35, 8.1, 8.85] {
            pen.line([P.plan(u, 5.05, 0.5), P.plan(u, 5.05, 1.6)], tone(frame, 0.18), width: 1)
        }
        pen.box(6.6, 5.05, 0.1, 9.6, 8.8, 0.4, frame)
        pen.box(6.7, 5.05, 0.4, 9.5, 8.7, 0.65, 0xF4F1EA)
        pen.box(6.9, 5.15, 0.65, 8.0, 5.85, 0.88, 0xFFFFFF)
        pen.box(8.15, 5.15, 0.65, 9.3, 5.85, 0.86, 0xEDE6D8)
        pen.line([P.plan(7.0, 5.5, 0.88), P.plan(7.9, 5.5, 0.88)], tone(0xFFFFFF, -0.12), width: 1)
        pen.line([P.plan(8.25, 5.5, 0.86), P.plan(9.2, 5.5, 0.86)], tone(0xEDE6D8, -0.15), width: 1)
    }

    /// The blanket, folded at the foot or pulled up over HAKU.
    private static func blanket(_ pen: IsoPen, _ c: UInt32, covering: Bool) {
        if covering {
            pen.box(6.65, 6.3, 0.62, 9.55, 8.75, 0.82, c, top: tone(c, 0.12))
            pen.box(7.5, 6.6, 0.82, 8.7, 8.3, 0.96, c, top: tone(c, 0.18), line: 0)
            pen.line([P.plan(6.65, 6.3, 0.82), P.plan(9.55, 6.3, 0.82)], tone(c, 0.5), width: 3)
        } else {
            pen.box(6.65, 7.3, 0.62, 9.55, 8.75, 0.8, c, top: tone(c, 0.12))
            pen.line([P.plan(6.65, 7.9, 0.8), P.plan(9.55, 7.9, 0.8)], tone(c, -0.3), width: 1.6)
            pen.line([P.plan(6.65, 7.3, 0.78), P.plan(9.55, 7.3, 0.78)], tone(c, 0.45), width: 2.2)
            for x in [7.2, 8.0, 8.9] {
                pen.line([P.plan(x, 8.0, 0.8), P.plan(x + 0.25, 8.6, 0.8)], tone(c, -0.15), width: 1)
            }
        }
    }

    private static func nightstand(_ pen: IsoPen) {
        pen.box(9.0, 3.6, 0, 9.9, 4.5, 0.9, HomeColors.wood)
        pen.line([P.plan(9.1, 4.5, 0.45), P.plan(9.8, 4.5, 0.45)], tone(HomeColors.wood, -0.4), width: 1.5)
        pen.ellipse(at: P.plan(9.45, 4.5, 0.66), rx: 1.8, ry: 1.8, Color(hex: 0x1B1C26), line: 0)
        // A phone face down, the lamp.
        pen.box(9.1, 3.7, 0.9, 9.3, 4.0, 0.93, 0x1B1C26, line: 1)
        pen.box(9.35, 3.95, 0.9, 9.55, 4.15, 1.2, HomeColors.navy)
        pen.cylinder(9.45, 4.05, r: 0.25, 1.2, 1.6, 0xFFF0C8)
    }

    private static func floorLamp(_ pen: IsoPen) {
        // Mike 2026-10-18: the cord ran out across the floor like a stray line. It now runs to a socket beside it.
        pen.onLeftWall(7.72, 0.28, 7.98, 0.48, Color(hex: 0xFFFBF2), line: 1)
        pen.box(0, 7.79, 0.32, 0.07, 7.91, 0.44, 0x1B1C26)
        pen.line(
            [P.plan(0.07, 7.85, 0.34), P.plan(0.08, 7.88, 0.03), P.plan(0.16, 8.12, 0.02), P.plan(0.3, 8.28, 0.03)],
            Color(hex: 0x1B1C26), width: 1.4)
        pen.cylinder(0.5, 8.4, r: 0.28, 0, 0.1, 0x1B1C26)
        pen.cylinder(0.5, 8.4, r: 0.17, 0.4, 2.8, 0xFF5A7A)
        pen.line([P.plan(0.5, 8.4, 0.1), P.plan(0.5, 8.4, 0.4)], width: 3)
    }

    private static func doormat(_ pen: IsoPen) {
        pen.floor(3.6, 9.05, 5.6, 9.9, Color(hex: 0x3A3D52), z: 0.01)
        pen.floor(3.8, 9.25, 5.4, 9.7, Color(hex: 0x4E5270), z: 0.01, line: 0)
    }

    /// A pot with big leaves.
    private static func plant(_ pen: IsoPen, at x: Double, _ y: Double, size: Double, pot: UInt32) {
        let r = 0.28 * size
        pen.box(x - r, y - r, 0, x + r, y + r, 0.7 * size, pot)
        let top = HomeGrid.plan(x, y, 0.7 * size)
        let rx = CGFloat(r) * HomeGrid.unit * 0.9
        pen.ellipse(at: top, rx: rx, ry: rx / 2, Color(hex: 0x5B3A29), line: 0)
        let s = CGFloat(size)
        let leaves: [(CGFloat, CGFloat)] = [(-26, -30), (24, -34), (-8, -52), (10, -44), (-30, -10), (30, -14)]
        for (dx, dy) in leaves {
            var leaf = Path()
            leaf.move(to: top)
            let tip = CGPoint(x: top.x + dx * s, y: top.y + dy * s)
            leaf.addQuadCurve(to: tip, control: CGPoint(x: top.x + dx * s * 0.2 - 10 * s, y: top.y + dy * s * 0.7))
            leaf.addQuadCurve(to: top, control: CGPoint(x: top.x + dx * s * 0.9 + 6 * s, y: top.y + dy * s * 0.4))
            pen.context.fill(leaf, with: .color(Color(hex: HomeColors.leaf)))
            pen.context.stroke(
                leaf, with: .color(IsoPen.ink), style: StrokeStyle(lineWidth: 2 * IsoPen.weight, lineJoin: .round))
            let mid = CGPoint(x: (top.x + tip.x) / 2 + dx * s * 0.05, y: (top.y + tip.y) / 2)
            pen.line([top, mid, tip], tone(HomeColors.leaf, -0.3), width: 1)
        }
    }

    // MARK: Shop items

    /// The boxes an item's drawing fills.
    static func boxes(_ item: HomeItem) -> [GridBox] {
        let s = item.spot
        switch item {
        case .plant: return [GridBox(x0: s.x - 1.2, y0: s.y - 1.2, x1: s.x + 0.6, y1: s.y + 0.6, z1: 2.6)]
        case .bench: return [GridBox(x0: 3.4, y0: 0.1, x1: 5.7, y1: 3.5, z1: 2.1)]
        case .snowboard: return [GridBox(x0: s.x - 0.3, y0: 0, x1: s.x + 0.3, y1: 0.4, z1: 3.8)]
        case .gloves, .racket:
            return [GridBox(x0: s.x - 0.5, y0: 0, x1: s.x + 0.5, y1: 0.4, z0: s.z - 0.8, z1: s.z + 0.9)]
        case .cactus:
            return [GridBox(x0: s.x - 0.25, y0: s.y - 0.25, x1: s.x + 0.25, y1: s.y + 0.25, z0: s.z, z1: s.z + 0.7)]
        case .speaker: return [GridBox(x0: s.x - 0.35, y0: s.y - 0.35, x1: s.x + 0.35, y1: s.y + 0.35, z1: 1)]
        case .bag: return [GridBox(x0: s.x - 0.5, y0: s.y - 0.5, x1: s.x + 0.5, y1: s.y + 0.5, z0: s.z, z1: s.z + 2.8)]
        case .clipLamp, .headphones, .gamepad, .cube:
            return [GridBox(x0: s.x - 0.3, y0: s.y - 0.3, x1: s.x + 0.45, y1: s.y + 0.3, z0: s.z, z1: s.z + 1.0)]
        case .comics: return [GridBox(x0: s.x - 0.35, y0: s.y - 0.35, x1: s.x + 0.35, y1: s.y + 0.35, z1: 0.5)]
        case .fan: return [GridBox(x0: s.x - 0.4, y0: s.y - 0.45, x1: s.x + 0.4, y1: s.y + 0.45, z1: 1.35)]
        case .monstera: return [GridBox(x0: s.x - 1.3, y0: s.y - 1.3, x1: s.x + 0.7, y1: s.y + 0.7, z1: 2.9)]
        case .skateboard: return [GridBox(x0: 0, y0: s.y - 0.3, x1: s.x + 0.15, y1: s.y + 0.3, z1: 1.8)]
        case .arcadePoster, .cityPoster: return [HomeZone.posterWall.box ?? GridBox(x0: 0, y0: 0, x1: 0, y1: 0, z1: 0)]
        case .mat: return [GridBox(x0: 3.95, y0: 0.45, x1: 5.15, y1: 3.4, z1: 0.45)]
        case .rope:
            return [GridBox(x0: s.x - 0.4, y0: 0, x1: s.x + 0.4, y1: 0.4, z0: s.z - 1.2, z1: s.z + 0.7)]
        case .danceMirror: return [GridBox(x0: s.x - 0.45, y0: 0, x1: s.x + 0.45, y1: 0.2, z0: 0.5, z1: s.z + 1.75)]
        case .musicStand: return [GridBox(x0: s.x - 0.6, y0: s.y - 0.6, x1: s.x + 0.6, y1: s.y + 0.6, z1: 2.5)]
        }
    }

    static func item(_ pen: IsoPen, _ item: HomeItem) {
        let s = item.spot
        let p = { (x: Double, y: Double, z: Double) in HomeGrid.plan(x, y, z) }
        switch item {
        case .plant:
            pen.contact(s.x - 0.35, s.y - 0.35, s.x + 0.35, s.y + 0.35)
            plant(pen, at: s.x, s.y, size: 1.2, pot: 0xFF3EA5)
        case .bag:
            // A standing bag: weighted base, short post, the bag with a domed top and two straps.
            pen.contact(s.x - 0.45, s.y - 0.45, s.x + 0.45, s.y + 0.45)
            pen.cylinder(s.x, s.y, r: 0.4, 0, 0.3, 0x2D3250)
            pen.cylinder(s.x, s.y, r: 0.12, 0.3, 0.5, 0x1B1C26)
            pen.cylinder(s.x, s.y, r: 0.28, 0.5, 2.3, 0xFF3B4E)
            pen.ellipse(at: p(s.x, s.y, 2.38), rx: 0.28 * HomeGrid.unit * 1.22, ry: 9, Color(hex: 0xFF3B4E), line: 2)
            for z in [1.0, 1.8] {
                let rx = 0.28 * HomeGrid.unit * 1.22
                let c = p(s.x, s.y, z)
                pen.line([CGPoint(x: c.x - rx, y: c.y), CGPoint(x: c.x + rx, y: c.y)], Color(hex: 0x2F3557), width: 4)
            }
        case .cactus:
            pen.box(s.x - 0.14, s.y - 0.14, s.z, s.x + 0.14, s.y + 0.14, s.z + 0.22, 0xD9774A)
            pen.cylinder(s.x, s.y, r: 0.08, s.z + 0.22, s.z + 0.62, 0x58C25A, line: 1.8)
            pen.line([p(s.x, s.y, s.z + 0.42), p(s.x - 0.16, s.y + 0.16, s.z + 0.5)], Color(hex: 0x58C25A), width: 5)
        case .speaker:
            pen.contact(s.x - 0.3, s.y - 0.3, s.x + 0.3, s.y + 0.3)
            pen.box(s.x - 0.3, s.y - 0.3, 0, s.x + 0.3, s.y + 0.3, 0.85, 0x1B1C26)
            pen.ellipse(at: p(s.x, s.y + 0.3, 0.55), rx: 6, ry: 6.5, Color(hex: 0x3A3D52), line: 1.8)
            pen.ellipse(at: p(s.x, s.y + 0.3, 0.55), rx: 2.5, ry: 2.5, Color(hex: 0x3EF0FF), line: 0)
            pen.ellipse(at: p(s.x, s.y + 0.3, 0.22), rx: 3.5, ry: 3.5, Color(hex: 0x3A3D52), line: 1.4)
        case .gloves:
            // A pair on a hook, hanging by the laces.
            pen.box(s.x - 0.05, 0, s.z + 0.45, s.x + 0.05, 0.12, s.z + 0.55, 0xC3C8D2, line: 1.4)
            for (dx, dz) in [(-0.14, 0.0), (0.14, -0.1)] {
                pen.line([p(s.x, 0.12, s.z + 0.5), p(s.x + dx, 0.16, s.z + dz + 0.3)], width: 1.2)
                pen.ellipse(at: p(s.x + dx, 0.16, s.z + dz), rx: 7, ry: 9, Color(hex: 0xFF3B4E), line: 1.8)
                pen.ellipse(at: p(s.x + dx, 0.16, s.z + dz + 0.24), rx: 4.5, ry: 2.5, Color(hex: 0xF4F1EA), line: 1.4)
            }
        case .racket:
            let head = (0..<24).map { i in
                let a = Double(i) / 24 * 2 * .pi
                return p(s.x + 0.24 * cos(a), s.y, s.z + 0.5 + 0.32 * sin(a))
            }
            pen.box(s.x - 0.03, s.y, s.z - 0.45, s.x + 0.03, s.y + 0.06, s.z + 0.18, 0x1B1C26, line: 1.4)
            pen.polygon(head, Color.white.opacity(0.25), line: 1.6)
            for k in [-0.12, 0.0, 0.12] {
                pen.line(
                    [p(s.x + k, s.y, s.z + 0.22), p(s.x + k, s.y, s.z + 0.78)], Color(hex: 0x3EC8FF).opacity(0.7),
                    width: 0.8)
                pen.line(
                    [p(s.x - 0.2, s.y, s.z + 0.5 + k * 1.6), p(s.x + 0.2, s.y, s.z + 0.5 + k * 1.6)],
                    Color(hex: 0x3EC8FF).opacity(0.7), width: 0.8)
            }
            var ring = Path()
            ring.addLines(head)
            ring.closeSubpath()
            pen.context.stroke(ring, with: .color(Color(hex: 0x3EC8FF)), lineWidth: 2.4)
        case .snowboard:
            // Leaning against the back wall, nose up.
            pen.box(s.x - 0.19, 0.05, 0.05, s.x + 0.19, 0.17, 3.55, 0xFFD23F)
            pen.onBackWall(y: 0.17, s.x - 0.15, 2.4, s.x + 0.15, 2.9, Color(hex: HomeColors.pink), line: 1.2)
            pen.onBackWall(y: 0.17, s.x - 0.12, 0.8, s.x + 0.12, 1.1, Color(hex: 0x1B1C26), line: 1)
            pen.onBackWall(y: 0.17, s.x - 0.12, 1.7, s.x + 0.12, 2.0, Color(hex: 0x1B1C26), line: 1)
        case .bench:
            // Rack uprights with their feet and the padded bench; the bar is its own layer, `barbell`.
            // The rack stands against the wall so HAKU's head fits on the pad in front of it.
            pen.contact(3.85, 0.25, 5.3, 3.4)
            for x in [4.1, 5.05] {
                pen.box(x - 0.2, 0.25, 0, x + 0.2, 0.55, 0.06, 0x2A2C34)
                pen.box(x - 0.06, 0.35, 0, x + 0.06, 0.47, 1.9, 0x2A2C34)
            }
            pen.box(4.5, 1.1, 0, 4.65, 3.3, 0.45, 0x2A2C34)
            pen.box(4.3, 1.0, 0.45, 4.85, 3.4, 0.62, HomeColors.navy, top: tone(HomeColors.navy, 0.2))
            pen.line([p(4.85, 1.05, 0.55), p(4.85, 3.35, 0.55)], tone(HomeColors.navy, 0.25), width: 1)
        case .clipLamp: clipLamp(pen, at: s)
        case .headphones: headphones(pen, at: s)
        case .gamepad: gamepad(pen, at: s)
        case .cube: cube(pen, at: s)
        case .comics: comics(pen, at: s)
        case .fan: fan(pen, at: s)
        case .monstera: monstera(pen, at: s)
        case .skateboard: skateboard(pen, at: s)
        case .arcadePoster: arcadePoster(pen)
        case .cityPoster: cityPoster(pen)
        case .mat: mat(pen, at: s)
        case .rope: rope(pen, at: s)
        case .danceMirror: danceMirror(pen, at: s)
        case .musicStand: musicStand(pen, at: s)
        }
    }

    // MARK: Shared items

    /// A yoga mat rolled out along the sports floor, its far end still rolled up against the wall.
    private static func mat(_ pen: IsoPen, at s: GridPoint) {
        let lilac: UInt32 = 0x9C8CFF
        let (x0, x1) = (s.x - 0.5, s.x + 0.5)
        pen.floor(x0, 0.85, x1, 3.3, Color(hex: lilac), z: 0.02, line: 2)
        pen.floor(x0 + 0.08, 0.95, x1 - 0.08, 3.2, tone(lilac, 0.2), z: 0.02, line: 0)
        for y in stride(from: 1.2, to: 3.2, by: 0.35) {
            pen.line(
                [HomeGrid.plan(x0 + 0.1, y, 0.02), HomeGrid.plan(x1 - 0.1, y, 0.02)], tone(lilac, -0.12), width: 0.8)
        }
        // The roll: its side, then its round end facing the room with the mat's spiral.
        let (y, z, r) = (0.72, 0.17, 0.17)
        pen.box(GridBox(x0: x0, y0: y - r, x1: x1, y1: y + r, z0: 0, z1: 2 * r), lilac, line: 0)
        pen.line([HomeGrid.plan(x0, y + r, z), HomeGrid.plan(x1, y + r, z)], width: 2)
        pen.line([HomeGrid.plan(x0, y - 0.02, 2 * r), HomeGrid.plan(x1, y - 0.02, 2 * r)], width: 2)
        pen.line(
            [HomeGrid.plan(x0, y + 0.1, 2 * r - 0.02), HomeGrid.plan(x1, y + 0.1, 2 * r - 0.02)], tone(lilac, 0.4),
            width: 1.2)
        pen.discAcross(x: x1, y, z, r: r, tone(lilac, -0.15), line: 1.8)
        let spiral = (0..<28).map { i -> CGPoint in
            let a = Double(i) / 28 * 4 * .pi
            let k = r * 0.85 * (1 - Double(i) / 32)
            return HomeGrid.plan(x1, y + k * cos(a), z + k * sin(a))
        }
        pen.line(spiral, tone(lilac, 0.35), width: 1)
        pen.contact(x0, y - r, x1, y + r)
    }

    /// A jump rope hanging from a hook by its handles, the rope looping below.
    private static func rope(_ pen: IsoPen, at s: GridPoint) {
        let p = { (x: Double, z: Double) in HomeGrid.plan(x, s.y, z) }
        let hook = p(s.x, s.z + 0.5)
        pen.box(s.x - 0.05, 0, s.z + 0.45, s.x + 0.05, 0.12, s.z + 0.55, 0xC3C8D2, line: 1.4)
        // The rope: from each handle's bottom, down in a loop under them.
        var loop = Path()
        loop.move(to: p(s.x - 0.17, s.z - 0.12))
        loop.addCurve(
            to: p(s.x + 0.17, s.z - 0.12), control1: p(s.x - 0.32, s.z - 1.25), control2: p(s.x + 0.3, s.z - 1.2))
        pen.context.stroke(loop, with: .color(IsoPen.ink), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
        pen.context.stroke(
            loop, with: .color(Color(hex: 0x3EC8FF)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        var inner = Path()
        inner.move(to: p(s.x - 0.12, s.z - 0.12))
        inner.addCurve(
            to: p(s.x + 0.12, s.z - 0.12), control1: p(s.x - 0.22, s.z - 0.85), control2: p(s.x + 0.2, s.z - 0.8))
        pen.context.stroke(inner, with: .color(IsoPen.ink), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
        pen.context.stroke(
            inner, with: .color(Color(hex: 0x3EC8FF)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        // Handles hanging off the hook by short cords.
        for dx in [-0.15, 0.15] {
            let top = p(s.x + dx, s.z + 0.28)
            pen.line([hook, top], width: 1.2)
            let handle = Path(roundedRect: CGRect(x: top.x - 3, y: top.y, width: 6, height: 15), cornerRadius: 3)
            pen.context.fill(handle, with: .color(Color(hex: HomeColors.pink)))
            pen.context.stroke(handle, with: .color(IsoPen.ink), lineWidth: 1.6 * IsoPen.weight)
            pen.line(
                [CGPoint(x: top.x - 2, y: top.y + 3), CGPoint(x: top.x - 2, y: top.y + 11)], Color.white.opacity(0.5),
                width: 1)
        }
    }

    /// A tall dance mirror on the sports wall, in a light wood frame, with the room's light on the glass.
    private static func danceMirror(_ pen: IsoPen, at s: GridPoint) {
        let (u0, u1, v0, v1) = (s.x - 0.38, s.x + 0.38, 0.55, s.z + 1.7)
        pen.box(u0 - 0.06, 0, v0 - 0.06, u1 + 0.06, 0.06, v1 + 0.06, 0xE2B887, line: 2)
        pen.onBackWall(y: 0.065, u0, v0, u1, v1, Color(hex: 0xCFE9F5), line: 1.6)
        // A faint copy of the window's light, then two bright streaks.
        pen.onBackWall(y: 0.066, u0, v1 - 0.9, u0 + 0.3, v1, Color.white.opacity(0.35), line: 0)
        for (a, b, w) in [(0.15, 0.9, 3.0), (0.4, 1.3, 1.6)] {
            pen.line(
                [HomeGrid.plan(u0 + a, 0.066, v1 - 0.2), HomeGrid.plan(u0 + a + 0.3, 0.066, v1 - b)],
                Color.white.opacity(0.75), width: w)
        }
        pen.line(
            [HomeGrid.plan(u1 - 0.2, 0.066, v0 + 0.5), HomeGrid.plan(u1 - 0.05, 0.066, v0 + 0.25)],
            Color.white.opacity(0.6), width: 1.6)
    }

    /// A black folding music stand with a page of music on it, facing the room.
    private static func musicStand(_ pen: IsoPen, at s: GridPoint) {
        let p = { (x: Double, y: Double, z: Double) in HomeGrid.plan(x, y, z) }
        let black = Color(hex: 0x1B1C26)
        pen.contact(s.x - 0.35, s.y - 0.35, s.x + 0.35, s.y + 0.35)
        for (dx, dy) in [(-0.35, -0.2), (0.3, -0.25), (0.05, 0.38)] {
            pen.line([p(s.x, s.y, 0.45), p(s.x + dx, s.y + dy, 0)], width: 2.6)
        }
        pen.line([p(s.x, s.y, 0.45), p(s.x, s.y, 1.55)], width: 3)
        pen.line([p(s.x, s.y, 0.45), p(s.x, s.y, 1.55)], Color(hex: 0x3A3D52), width: 1.2)
        // The desk leans back: its bottom edge in front, its top towards the wall.
        let (b, t) = ((x: s.x + 0.05, z: 1.5), (x: s.x - 0.2, z: 2.25))
        let (y0, y1) = (s.y - 0.48, s.y + 0.48)
        pen.polygon([p(b.x, y0, b.z), p(b.x, y1, b.z), p(t.x, y1, t.z), p(t.x, y0, t.z)], black, line: 2)
        pen.box(
            GridBox(x0: b.x - 0.02, y0: y0, x1: b.x + 0.1, y1: y1, z0: b.z - 0.06, z1: b.z + 0.04), 0x1B1C26, line: 1.4)
        // The page and its staves with a few notes.
        let page = { (u: Double, v: Double) in
            p(b.x + (t.x - b.x) * v - 0.02, y0 + 0.1 + u * (y1 - y0 - 0.2), b.z + 0.04 + (t.z - b.z - 0.06) * v)
        }
        pen.polygon([page(0, 0), page(1, 0), page(1, 1), page(0, 1)], Color(hex: 0xFFFBF2), line: 1.2)
        for v in [0.3, 0.55, 0.8] {
            pen.line([page(0.08, v), page(0.92, v)], Color(hex: 0x6B6F85), width: 0.8)
        }
        for (u, v) in [(0.2, 0.33), (0.38, 0.27), (0.6, 0.58), (0.78, 0.52), (0.5, 0.83)] {
            pen.ellipse(at: page(u, v), rx: 1.6, ry: 1.2, black, line: 0)
            pen.line([page(u + 0.02, v), page(u + 0.02, v + 0.12)], black, width: 0.8)
        }
    }

    // MARK: Desk items, standing at the desk's first slot

    /// A yellow clamp lamp: clamp on the desk, two arms, the shade tipped down at the desk.
    private static func clipLamp(_ pen: IsoPen, at s: GridPoint) {
        let p = { (x: Double, y: Double, z: Double) in HomeGrid.plan(x, y, z) }
        let yellow: UInt32 = 0xFFD23F
        pen.box(s.x - 0.1, s.y - 0.1, s.z, s.x + 0.1, s.y + 0.1, s.z + 0.08, 0x2A2C38)
        let elbow = p(s.x - 0.05, s.y, s.z + 0.62)
        let head = p(s.x + 0.25, s.y - 0.05, s.z + 0.82)
        pen.line([p(s.x, s.y, s.z + 0.08), elbow, head], width: 2.6)
        pen.line([p(s.x, s.y, s.z + 0.08), elbow, head], Color(hex: yellow), width: 1.2)
        pen.ellipse(at: elbow, rx: 2.2, ry: 2.2, Color(hex: 0x2A2C38), line: 1)
        // The shade, a cone opening down towards the desk front, with the bulb's glow under it.
        var shade = Path()
        shade.move(to: CGPoint(x: head.x - 3, y: head.y - 3))
        shade.addLine(to: CGPoint(x: head.x + 3, y: head.y - 4))
        shade.addLine(to: CGPoint(x: head.x + 11, y: head.y + 7))
        shade.addQuadCurve(to: CGPoint(x: head.x - 2, y: head.y + 10), control: CGPoint(x: head.x + 6, y: head.y + 13))
        shade.closeSubpath()
        pen.context.fill(shade, with: .color(Color(hex: yellow)))
        pen.context.stroke(shade, with: .color(IsoPen.ink), style: StrokeStyle(lineWidth: 1.8 * IsoPen.weight))
        pen.line(
            [CGPoint(x: head.x - 1, y: head.y - 1), CGPoint(x: head.x + 7, y: head.y + 6)], tone(yellow, 0.6), width: 1)
        pen.ellipse(at: CGPoint(x: head.x + 4.5, y: head.y + 9.5), rx: 3, ry: 1.8, Color(hex: 0xFFF6D0), line: 1)
    }

    /// Headphones hanging on a little stand.
    private static func headphones(_ pen: IsoPen, at s: GridPoint) {
        let p = { (x: Double, y: Double, z: Double) in HomeGrid.plan(x, y, z) }
        pen.cylinder(s.x, s.y, r: 0.15, s.z, s.z + 0.05, 0x2A2C38, line: 1.6)
        pen.box(s.x - 0.03, s.y - 0.03, s.z + 0.05, s.x + 0.03, s.y + 0.03, s.z + 0.72, 0x2A2C38, line: 1.4)
        let left = p(s.x, s.y - 0.17, s.z + 0.45)
        let right = p(s.x, s.y + 0.17, s.z + 0.45)
        var band = Path()
        band.move(to: CGPoint(x: left.x, y: left.y - 4))
        band.addQuadCurve(to: CGPoint(x: right.x, y: right.y - 4), control: p(s.x, s.y, s.z + 1.02))
        pen.context.stroke(band, with: .color(IsoPen.ink), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))
        pen.context.stroke(
            band, with: .color(Color(hex: HomeColors.navy)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        for (c, k) in [(left, -0.15), (right, 0.0)] {
            pen.ellipse(at: c, rx: 4.6, ry: 6, tone(HomeColors.pink, k), line: 1.6)
            pen.ellipse(at: CGPoint(x: c.x + 0.8, y: c.y), rx: 2.2, ry: 3.4, Color(hex: 0x2A2C38), line: 0)
        }
    }

    /// A game controller lying on the desk: d-pad on one grip, four buttons on the other.
    private static func gamepad(_ pen: IsoPen, at s: GridPoint) {
        let p = { (x: Double, y: Double, z: Double) in HomeGrid.plan(x, y, z) }
        let body: UInt32 = 0x2A2C38
        let z = s.z + 0.07
        for dy in [-0.17, 0.17] {
            pen.box(s.x - 0.05, s.y + dy - 0.09, s.z, s.x + 0.2, s.y + dy + 0.09, z, body, line: 1.6)
        }
        pen.box(s.x - 0.12, s.y - 0.24, s.z, s.x + 0.1, s.y + 0.24, z, body, top: tone(body, 0.2), line: 1.6)
        // D-pad.
        let d = p(s.x, s.y - 0.14, z)
        pen.line([CGPoint(x: d.x - 3, y: d.y), CGPoint(x: d.x + 3, y: d.y)], Color(hex: 0xC3C8D2), width: 1.6)
        pen.line([CGPoint(x: d.x, y: d.y - 2), CGPoint(x: d.x, y: d.y + 2)], Color(hex: 0xC3C8D2), width: 1.6)
        // Buttons.
        let b = p(s.x, s.y + 0.14, z)
        for (dx, dy, c) in [
            (CGFloat(-2.6), CGFloat(0), UInt32(0xFF3EA5)), (2.6, 0, 0x3EF0FF), (0, -1.6, 0xFFD23F), (0, 1.6, 0x7CFF4F),
        ] {
            pen.ellipse(at: CGPoint(x: b.x + dx, y: b.y + dy), rx: 1.2, ry: 0.9, Color(hex: c), line: 0)
        }
        pen.ellipse(at: p(s.x - 0.02, s.y, z), rx: 1.6, ry: 0.9, Color(hex: 0x3EF0FF).opacity(0.8), line: 0)
    }

    /// A puzzle cube, three by three on every face, a bit scrambled.
    private static func cube(_ pen: IsoPen, at s: GridPoint) {
        let n = 3
        let side = 0.3
        let (x0, y0, z0) = (s.x - side / 2, s.y - side / 2, s.z)
        let (x1, y1, z1) = (x0 + side, y0 + side, z0 + side)
        let cell = side / Double(n)
        let colours: [UInt32] = [0xFF3B4E, 0xFFFFFF, 0xFFD23F, 0x3E8BFF, 0x58C25A, 0xFF9F43]
        func colour(_ face: Int, _ i: Int, _ j: Int) -> Color {
            // The middle sticker names the face; the rest are a fixed scramble.
            let k = i == 1 && j == 1 ? face : (face * 7 + i * 5 + j * 3) % colours.count
            return Color(hex: colours[k])
        }
        pen.box(x0, y0, z0, x1, y1, z1, 0x1B1C26, line: 1.8)
        for i in 0..<n {
            for j in 0..<n {
                let a = Double(i) * cell
                let b = Double(j) * cell
                let e = 0.012
                // Top (z = z1), front-left (y = y1), front-right (x = x1).
                pen.polygon(
                    [
                        HomeGrid.plan(x0 + a + e, y0 + b + e, z1), HomeGrid.plan(x0 + a + cell - e, y0 + b + e, z1),
                        HomeGrid.plan(x0 + a + cell - e, y0 + b + cell - e, z1),
                        HomeGrid.plan(x0 + a + e, y0 + b + cell - e, z1),
                    ], colour(0, i, j), line: 0)
                pen.onBackWall(
                    y: y1, x0 + a + e, z0 + b + e, x0 + a + cell - e, z0 + b + cell - e, colour(1, i, j).opacity(0.85),
                    line: 0)
                pen.onLeftWall(
                    x: x1, y0 + a + e, z0 + b + e, y0 + a + cell - e, z0 + b + cell - e, colour(2, i, j).opacity(0.7),
                    line: 0)
            }
        }
    }

    // MARK: Beside the sofa

    /// A stack of five comics, the top one's cover up.
    private static func comics(_ pen: IsoPen, at s: GridPoint) {
        pen.contact(s.x - 0.28, s.y - 0.22, s.x + 0.28, s.y + 0.22)
        let spines: [UInt32] = [0x3E8BFF, 0xFF3EA5, 0xFFD23F, 0x58C25A, 0xFF9F43]
        var z = 0.0
        for (i, c) in spines.enumerated() {
            let dx = [0.0, 0.04, -0.03, 0.05, -0.02][i]
            let dy = [0.0, -0.03, 0.04, 0.0, -0.04][i]
            let h = 0.07
            pen.box(
                GridBox(
                    x0: s.x - 0.25 + dx, y0: s.y - 0.19 + dy, x1: s.x + 0.25 + dx, y1: s.y + 0.19 + dy, z0: z, z1: z + h
                ),
                0xFFF6E5, top: Color(hex: c), left: Color(hex: c), right: Color(hex: 0xFFF6E5), line: 1.4)
            z += h
        }
        // The top cover: a burst and a title strip.
        let top = HomeGrid.plan(s.x - 0.02, s.y - 0.04, z)
        var burst = Path()
        for k in 0..<12 {
            let a = Double(k) / 12 * 2 * .pi
            let r = k.isMultiple(of: 2) ? 5.5 : 3.0
            let q = CGPoint(x: top.x + CGFloat(r * cos(a)) * 1.3, y: top.y + CGFloat(r * sin(a)) * 0.65)
            if k == 0 { burst.move(to: q) } else { burst.addLine(to: q) }
        }
        burst.closeSubpath()
        pen.context.fill(burst, with: .color(Color(hex: 0xFFFFFF)))
        pen.context.stroke(burst, with: .color(IsoPen.ink), lineWidth: 0.9)
        pen.line(
            [HomeGrid.plan(s.x - 0.2, s.y + 0.12, z), HomeGrid.plan(s.x + 0.15, s.y + 0.12, z)], Color(hex: 0x1B1C26),
            width: 1.6)
    }

    /// A small floor fan facing the room: round foot, post, the cage with three blades.
    private static func fan(_ pen: IsoPen, at s: GridPoint) {
        let mint: UInt32 = 0x6FD6C2
        let hub = (y: s.y, z: 0.9)
        pen.contact(s.x - 0.25, s.y - 0.25, s.x + 0.25, s.y + 0.25)
        pen.cylinder(s.x, s.y, r: 0.24, 0, 0.07, mint, line: 1.6)
        pen.box(s.x - 0.04, s.y - 0.04, 0.07, s.x + 0.04, s.y + 0.04, 0.62, tone(mint, -0.2), line: 1.4)
        pen.discAcross(x: s.x - 0.08, hub.y, hub.z, r: 0.1, tone(mint, -0.25), line: 1.4)
        pen.discAcross(x: s.x, hub.y, hub.z, r: 0.36, Color.white.opacity(0.35), line: 2)
        for k in 0..<3 {
            let a = Double(k) / 3 * 2 * .pi + 0.4
            let points = stride(from: -0.5, through: 0.5, by: 0.25).map { t in
                HomeGrid.plan(s.x + 0.01, hub.y + 0.27 * cos(a + t * 0.9), hub.z + 0.27 * sin(a + t * 0.9))
            }
            pen.polygon(
                [HomeGrid.plan(s.x + 0.01, hub.y, hub.z)] + points, Color(hex: 0xFFFFFF).opacity(0.85), line: 1.1)
        }
        // Cage wires.
        for k in 0..<8 {
            let a = Double(k) / 8 * 2 * .pi
            pen.line(
                [
                    HomeGrid.plan(s.x + 0.02, hub.y, hub.z),
                    HomeGrid.plan(s.x + 0.02, hub.y + 0.36 * cos(a), hub.z + 0.36 * sin(a)),
                ], tone(mint, -0.35), width: 0.7)
        }
        pen.discAcross(x: s.x + 0.03, hub.y, hub.z, r: 0.06, Color(hex: mint), line: 1.2)
    }

    // MARK: Corner

    /// A monstera in a tall pot, its big leaves split to the edge.
    private static func monstera(_ pen: IsoPen, at s: GridPoint) {
        pen.contact(s.x - 0.35, s.y - 0.35, s.x + 0.35, s.y + 0.35)
        pen.cylinder(s.x, s.y, r: 0.3, 0, 0.75, 0xFFF6E5)
        pen.line(
            [HomeGrid.plan(s.x - 0.3, s.y, 0.6), HomeGrid.plan(s.x + 0.25, s.y + 0.15, 0.6)], tone(0xFFF6E5, -0.25),
            width: 1)
        let top = HomeGrid.plan(s.x, s.y, 0.75)
        pen.ellipse(at: top, rx: 11, ry: 5.5, Color(hex: 0x5B3A29), line: 0)
        let green: UInt32 = 0x2F9E5B
        // (tip of the stem, leaf size, which way the leaf points in radians from straight down), back leaves first.
        let leaves: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (-16, -60, 17, 2.5), (16, -66, 18, -2.5), (-28, -34, 15, 1.75), (28, -38, 16, -1.75), (2, -40, 15, -0.25),
        ]
        for (dx, dy, size, tilt) in leaves {
            let stem = CGPoint(x: top.x + dx, y: top.y + dy)
            pen.line([CGPoint(x: top.x + dx * 0.1, y: top.y - 2), stem], tone(green, -0.25), width: 1.8)
            monsteraLeaf(pen, at: stem, size: size, tilt: tilt, green)
        }
    }

    /// One heart-shaped leaf hanging from `stem`, with slits cut through to what is behind it.
    private static func monsteraLeaf(_ pen: IsoPen, at stem: CGPoint, size: CGFloat, tilt: Double, _ green: UInt32) {
        var c = pen.context
        c.translateBy(x: stem.x, y: stem.y)
        c.rotate(by: .radians(tilt))
        var leaf = Path()
        leaf.move(to: .zero)
        leaf.addCurve(
            to: CGPoint(x: 0, y: size * 1.25), control1: CGPoint(x: -size * 1.15, y: -size * 0.45),
            control2: CGPoint(x: -size * 0.9, y: size * 1.0))
        leaf.addCurve(
            to: .zero, control1: CGPoint(x: size * 0.9, y: size * 1.0),
            control2: CGPoint(x: size * 1.15, y: -size * 0.45))
        leaf.closeSubpath()
        c.fill(leaf, with: .color(Color(hex: green)))
        c.stroke(leaf, with: .color(IsoPen.ink), style: StrokeStyle(lineWidth: 1.8 * IsoPen.weight, lineJoin: .round))
        // Slits from the edge towards the midrib, both sides.
        var cut = c
        cut.blendMode = .clear
        for t in [0.3, 0.55, 0.8] as [CGFloat] {
            for side in [-1.0, 1.0] as [CGFloat] {
                var slit = Path()
                slit.move(to: CGPoint(x: side * size * 0.95, y: size * (t - 0.05)))
                slit.addLine(to: CGPoint(x: side * size * 0.3, y: size * (t + 0.08)))
                cut.stroke(slit, with: .color(.black), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            }
        }
        c.stroke(
            Path {
                $0.move(to: CGPoint(x: 0, y: 2))
                $0.addLine(to: CGPoint(x: 0, y: size * 1.1))
            },
            with: .color(tone(green, -0.3)), lineWidth: 1)
        c.stroke(
            Path {
                $0.move(to: CGPoint(x: -size * 0.5, y: size * 0.05))
                $0.addLine(to: CGPoint(x: -size * 0.2, y: size * 0.2))
            },
            with: .color(tone(green, 0.35)), lineWidth: 1.2)
    }

    /// A skateboard on its tail, leaning back on the left wall, grip side out.
    private static func skateboard(_ pen: IsoPen, at s: GridPoint) {
        let (y0, y1) = (s.y - 0.19, s.y + 0.19)
        let tail = (x: s.x - 0.05, z: 0.05)
        let nose = (x: 0.12, z: 1.62)
        // Along the deck, 0 at the tail, 1 at the nose; `out` lifts off the deck towards the room.
        func at(_ t: Double, _ y: Double, out: Double = 0) -> CGPoint {
            let x = tail.x + (nose.x - tail.x) * t + out * 0.89
            let z = tail.z + (nose.z - tail.z) * t + out * 0.45
            return HomeGrid.plan(x, y, z)
        }
        pen.contact(s.x - 0.25, y0, s.x + 0.1, y1)
        // Wheels and trucks under the deck, towards the wall.
        for t in [0.16, 0.84] {
            for y in [y0 - 0.02, y1 + 0.02] {
                pen.ellipse(at: at(t, y, out: -0.1), rx: 3.4, ry: 3.6, Color(hex: 0xFFF6E5), line: 1.4)
            }
            pen.line([at(t, y0, out: -0.08), at(t, y1, out: -0.08)], Color(hex: 0xC3C8D2), width: 2.4)
        }
        // The deck's pink edge, then the black grip on top with rounded ends.
        func outline(out: Double) -> [CGPoint] {
            let ends = 8
            var points: [CGPoint] = []
            for k in 0...ends {
                let a = Double(k) / Double(ends) * .pi
                points.append(at(0.06 - 0.06 * sin(a), s.y - 0.19 * cos(a), out: out))
            }
            for k in 0...ends {
                let a = Double(k) / Double(ends) * .pi
                points.append(at(0.94 + 0.06 * sin(a), s.y + 0.19 * cos(a), out: out))
            }
            return points
        }
        pen.polygon(outline(out: 0), Color(hex: HomeColors.pink), line: 1.8)
        pen.polygon(outline(out: 0.05), Color(hex: 0x23252F), line: 1.6)
        pen.line(
            [at(0.12, y1 - 0.04, out: 0.05), at(0.88, y1 - 0.04, out: 0.05)], Color.white.opacity(0.25), width: 1.2)
        for (t, y) in [(0.3, s.y - 0.08), (0.5, s.y + 0.06), (0.7, s.y - 0.02)] {
            pen.ellipse(at: at(t, y, out: 0.05), rx: 1, ry: 1, Color.white.opacity(0.3), line: 0)
        }
    }

    // MARK: Poster wall

    /// A poster on the left wall over the desk, from y `u0` to `u1` and z `v0` to `v1`, with tape on its corners.
    private static func posterFrame(
        _ pen: IsoPen, _ u0: Double, _ v0: Double, _ u1: Double, _ v1: Double, _ fill: Color
    ) {
        pen.onLeftWall(x: 0.02, u0, v0, u1, v1, fill, line: 2.2)
        for (u, v) in [(u0, v1), (u1, v1)] {
            pen.onLeftWall(x: 0.03, u - 0.1, v - 0.07, u + 0.1, v + 0.07, Color(hex: 0xFFF6E5).opacity(0.85), line: 0)
        }
    }

    /// A pixel-art arcade poster: a little pixel monster, hearts and a score row.
    private static func arcadePoster(_ pen: IsoPen) {
        let (u0, v0, u1, v1) = (0.85, 2.75, 3.05, 4.65)
        posterFrame(pen, u0, v0, u1, v1, Color(hex: 0x2A1B4A))
        let px = 0.13
        func pixel(_ col: Int, _ row: Int, at u: Double, _ v: Double, _ c: UInt32) {
            let a = u + Double(col) * px
            let b = v - Double(row) * px
            pen.onLeftWall(x: 0.025, a, b - px, a + px, b, Color(hex: c), line: 0)
        }
        // Score dots along the top.
        for i in 0..<6 { pixel(i * 2, 0, at: u0 + 0.25, v1 - 0.15, i < 4 ? 0xFFD23F : 0x6B5A8F) }
        // The monster.
        let monster = [
            "..XXXXX..",
            ".XXXXXXX.",
            "XX.XXX.XX",
            "XXXXXXXXX",
            "XXX...XXX",
            "X.X.X.X.X",
        ]
        for (row, line) in monster.enumerated() {
            for (col, ch) in line.enumerated() where ch == "X" {
                pixel(col, row, at: u0 + 0.5, v1 - 0.45, 0x7CFF4F)
            }
        }
        // Eyes and three hearts at the bottom.
        pixel(2, 2, at: u0 + 0.5, v1 - 0.45, 0xFFFFFF)
        pixel(6, 2, at: u0 + 0.5, v1 - 0.45, 0xFFFFFF)
        let heart = [".X.X.", "XXXXX", ".XXX.", "..X.."]
        for h in 0..<3 {
            for (row, line) in heart.enumerated() {
                for (col, ch) in line.enumerated() where ch == "X" {
                    let a = u0 + 0.3 + Double(h) * 0.62 + Double(col) * 0.09
                    let b = v0 + 0.6 - Double(row) * 0.09
                    pen.onLeftWall(x: 0.025, a, b - 0.09, a + 0.09, b, Color(hex: 0xFF3EA5), line: 0)
                }
            }
        }
        // A few stars.
        for (u, v) in [(0.95, 4.2), (2.95, 3.9), (1.05, 3.2), (2.85, 3.1)] {
            pen.onLeftWall(x: 0.025, u, v, u + 0.05, v + 0.05, Color.white.opacity(0.8), line: 0)
        }
    }

    /// A poster of a city at night: dusk sky, skyline with lit windows, a moon.
    private static func cityPoster(_ pen: IsoPen) {
        let (u0, v0, u1, v1) = (0.85, 2.75, 3.05, 4.65)
        posterFrame(pen, u0, v0, u1, v1, Color(hex: 0xFFF6E5))
        let (a0, b0, a1, b1) = (u0 + 0.1, v0 + 0.1, u1 - 0.1, v1 - 0.1)
        let x = 0.025
        pen.shade(
            [HomeGrid.plan(x, a0, b0), HomeGrid.plan(x, a1, b0), HomeGrid.plan(x, a1, b1), HomeGrid.plan(x, a0, b1)],
            .linearGradient(
                Gradient(colors: [Color(hex: 0x1C1F4A), Color(hex: 0x6A3A8A), Color(hex: 0xFF7A8A)]),
                startPoint: HomeGrid.plan(x, 2, b1), endPoint: HomeGrid.plan(x, 2, b0 + 0.5)))
        pen.ellipse(at: HomeGrid.plan(x, a1 - 0.45, b1 - 0.4), rx: 6, ry: 6, Color(hex: 0xFFF3C4), line: 0)
        pen.ellipse(at: HomeGrid.plan(x, a1 - 0.36, b1 - 0.34), rx: 5, ry: 5, Color(hex: 0x23255A), line: 0)
        let blocks: [(Double, Double, Double)] = [
            (0.0, 0.3, 0.9), (0.3, 0.5, 1.25), (0.5, 0.85, 0.75), (0.85, 1.05, 1.45), (1.05, 1.4, 1.0),
            (1.4, 1.6, 0.65), (1.6, 2.0, 1.15),
        ]
        for (i, (s0, s1, h)) in blocks.enumerated() {
            pen.onLeftWall(
                x: x, a0 + s0, b0, a0 + s1, b0 + h, Color(hex: i.isMultiple(of: 2) ? 0x1B1C3A : 0x262850), line: 0)
            var v = b0 + 0.15
            var k = i
            while v + 0.1 < b0 + h {
                var u = a0 + s0 + 0.05
                while u + 0.06 < a0 + s1 {
                    k += 1
                    if k % 3 != 0 { pen.onLeftWall(x: x, u, v, u + 0.05, v + 0.07, Color(hex: 0xFFD23F), line: 0) }
                    u += 0.11
                }
                v += 0.17
            }
        }
        // A thin neon line where the street is.
        pen.line([HomeGrid.plan(x, a0, b0 + 0.06), HomeGrid.plan(x, a1, b0 + 0.06)], Color(hex: 0x3EF0FF), width: 1.4)
    }

    /// The middle of the bar resting on the rack's hooks.
    static let racked = GridPoint(x: 4.575, y: 0.41, z: 1.75)

    /// The bench's bar with its plates, on the hooks; the scene moves it into HAKU's hands while he presses.
    static func barbell(_ pen: IsoPen) {
        let (y, z) = (racked.y, racked.z)
        let p = { (x: Double) in HomeGrid.plan(x, y, z) }
        // Short enough that both plates stay clear of the desk chair while HAKU presses.
        pen.discAcross(x: 3.97, y, z, r: 0.22, Color(hex: 0x1B1C26))
        pen.line([p(3.85), p(5.3)], Color(hex: 0xC3C8D2), width: 3)
        pen.line([p(3.85), p(5.3)], Color.white.opacity(0.6), width: 1)
        pen.discAcross(x: 5.18, y, z, r: 0.22, Color(hex: 0x1B1C26))
        pen.discAcross(x: 5.2, y, z, r: 0.07, Color(hex: 0xC3C8D2), line: 1)
    }

    /// The box the bar and its plates fill on the rack.
    static let barbellBox = GridBox(x0: 3.8, y0: 0.1, x1: 5.35, y1: 0.7, z0: 1.45, z1: 2.05)
}

/// What the desk monitor shows.
enum HomeScreen: Sendable {
    case off, code, sketch
}

#endif
