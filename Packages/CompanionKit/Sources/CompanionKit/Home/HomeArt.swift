#if os(iOS) || os(macOS)
import SwiftUI

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

    func polygon(_ points: [CGPoint], _ fill: Color, line: CGFloat = 2.2) {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        context.fill(path, with: .color(fill))
        if line > 0 {
            context.stroke(path, with: .color(Self.ink), style: StrokeStyle(lineWidth: line, lineJoin: .round))
        }
    }

    func line(_ points: [CGPoint], _ color: Color = IsoPen.ink, width: CGFloat = 2) {
        var path = Path()
        path.addLines(points)
        context.stroke(
            path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    /// The three visible faces of a box: front-left (y = y1), front-right (x = x1) and top.
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
        if line > 0 { context.stroke(path, with: .color(Self.ink), lineWidth: line) }
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

    /// Fills a plane quad with a gradient.
    func shade(_ points: [CGPoint], _ shading: GraphicsContext.Shading) {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        context.fill(path, with: shading)
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
}

/// The drawing of each room piece, in plan coordinates.
enum HomeArt {
    typealias P = HomeGrid

    // MARK: Shell

    /// Floor slab, floor and the two cut walls.
    static func shell(_ pen: IsoPen, walls: UInt32) {
        let n = HomeGrid.size
        let h = HomeGrid.wallHeight
        let w = HomeGrid.wallThickness
        // Slab under the floor.
        pen.box(
            GridBox(x0: -w, y0: -w, x1: n, y1: n, z0: -HomeGrid.slab, z1: 0), HomeColors.cut,
            top: tone(HomeColors.cut, 0), left: tone(HomeColors.cut, -0.08), right: tone(HomeColors.cut, -0.24))
        // Floor with planks along x.
        pen.floor(0, 0, n, n, Color(hex: HomeColors.floor))
        var y = 0.55
        var row = 0
        while y < n {
            pen.line([P.plan(0, y), P.plan(n, y)], tone(HomeColors.plank, 0.15), width: 1.4)
            var x = row.isMultiple(of: 2) ? 1.6 : 0.7
            while x < n {
                pen.line([P.plan(x, y - 0.55), P.plan(x, y)], tone(HomeColors.plank, 0.15), width: 1.2)
                x += 2.4
            }
            y += 0.55
            row += 1
        }
        // Warm light pooling on the floor.
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
        // Baseboards.
        pen.onBackWall(0, 0, n, 0.22, tone(walls, -0.18), line: 1.6)
        pen.onLeftWall(0, 0, n, 0.22, tone(walls, -0.24), line: 1.6)
        // Corner line.
        pen.line([P.plan(0, 0, 0), P.plan(0, 0, h)], tone(walls, -0.3), width: 1.6)
    }

    // MARK: Window

    static let window = (u0: 2.0, u1: 5.2, z0: 1.8, z1: 5.0)

    static func windowQuad() -> [CGPoint] {
        let w = window
        return [P.plan(w.u0, 0, w.z0), P.plan(w.u1, 0, w.z0), P.plan(w.u1, 0, w.z1), P.plan(w.u0, 0, w.z1)]
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
                startPoint: P.plan(3.6, 0, w.z1), endPoint: P.plan(3.6, 0, w.z0)))
        let sub = IsoPen(context: c)
        if night {
            sub.ellipse(at: P.plan(4.4, 0, 4.4), rx: 9, ry: 9, Color(hex: 0xFFF3C4), line: 0)
            for (u, v) in [(2.4, 4.6), (2.9, 4.2), (3.5, 4.75), (3.9, 4.1), (4.9, 4.7), (2.2, 3.9)] {
                sub.ellipse(at: P.plan(u, 0, v), rx: 1.3, ry: 1.3, .white, line: 0)
            }
        } else {
            sub.ellipse(at: P.plan(4.5, 0, 4.4), rx: 13, ry: 7, Color.white.opacity(0.9), line: 0)
            sub.ellipse(at: P.plan(4.2, 0, 4.25), rx: 9, ry: 5, Color.white.opacity(0.9), line: 0)
            sub.ellipse(at: P.plan(2.7, 0, 4.6), rx: 10, ry: 5, Color.white.opacity(0.8), line: 0)
        }
        // City blocks: far row, then near row.
        let far: [(Double, Double, Double)] = [
            (1.9, 2.4, 3.6), (2.4, 2.9, 3.1), (2.9, 3.3, 4.0), (3.3, 3.9, 3.4),
            (3.9, 4.3, 3.9), (4.3, 4.8, 3.2), (4.8, 5.3, 3.7),
        ]
        let near: [(Double, Double, Double)] = [
            (1.9, 2.6, 2.7), (2.6, 3.0, 3.2), (3.0, 3.8, 2.6), (3.8, 4.2, 3.0),
            (4.2, 4.9, 2.5), (4.9, 5.3, 2.9),
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

    /// Frame, cross bars, blind and sill.
    static func windowFrame(_ pen: IsoPen) {
        let w = window
        var outline = Path()
        outline.addLines(windowQuad())
        outline.closeSubpath()
        pen.context.stroke(outline, with: .color(IsoPen.ink), lineWidth: 5)
        pen.context.stroke(outline, with: .color(Color(hex: 0xFFF6E5)), lineWidth: 2)
        let mid = (w.u0 + w.u1) / 2
        pen.line([P.plan(mid, 0, w.z0), P.plan(mid, 0, w.z1)], IsoPen.ink, width: 4)
        pen.line([P.plan(w.u0, 0, 3.4), P.plan(w.u1, 0, 3.4)], IsoPen.ink, width: 4)
        // Rolled blind and sill.
        pen.box(w.u0 - 0.15, 0, w.z1 - 0.05, w.u1 + 0.15, 0.22, w.z1 + 0.3, HomeColors.navy)
        for u in stride(from: w.u0 + 0.15, to: w.u1, by: 0.45) {
            pen.line([P.plan(u, 0.22, w.z1 - 0.05), P.plan(u, 0.22, w.z1 + 0.3)], tone(HomeColors.navy, 0.2), width: 1)
        }
        pen.box(w.u0 - 0.2, 0, w.z0 - 0.12, w.u1 + 0.2, 0.32, w.z0, 0xF4E7D0)
    }

    // MARK: Furniture

    static func desk(_ pen: IsoPen) {
        let wood = HomeColors.wood
        for (x, y) in [(0.05, 0.5), (1.3, 0.5), (1.3, 2.3)] {
            pen.box(x, y, 0, x + 0.12, y + 0.12, 1.25, HomeColors.woodDark)
        }
        // Drawers.
        pen.box(0.1, 2.4, 0, 1.4, 3.3, 1.25, wood)
        for z in [0.42, 0.84] {
            pen.line([P.plan(0.15, 3.3, z), P.plan(1.35, 3.3, z)], tone(wood, -0.4), width: 1.5)
            pen.line([P.plan(1.4, 2.45, z), P.plan(1.4, 3.25, z)], tone(wood, -0.4), width: 1.5)
        }
        pen.line([P.plan(1.4, 2.75, 0.63), P.plan(1.4, 2.95, 0.63)], IsoPen.ink, width: 3)
        // Top.
        pen.box(0, 0.4, 1.25, 1.5, 3.4, 1.35, wood, top: tone(wood, 0.25))
        // Monitor on its stand.
        pen.box(0.3, 1.85, 1.35, 0.6, 2.15, 1.4, 0x2A2C38)
        pen.box(0.38, 1.94, 1.4, 0.48, 2.06, 1.72, 0x2A2C38)
        pen.box(0.2, 1.15, 1.62, 0.32, 2.85, 2.55, 0x1E2030, top: Color(hex: 0x3A3D52))
        // Keyboard and mouse.
        pen.box(0.68, 1.45, 1.35, 0.98, 2.55, 1.4, 0xF2F2F2)
        pen.box(0.8, 2.75, 1.35, 0.95, 2.88, 1.41, 0xF2F2F2)
        // Lamp: base, arm, shade.
        pen.box(0.25, 0.6, 1.35, 0.5, 0.85, 1.4, HomeColors.navy)
        pen.line([P.plan(0.37, 0.72, 1.4), P.plan(0.37, 0.72, 2.25), P.plan(0.62, 0.95, 2.4)], IsoPen.ink, width: 2.5)
        pen.box(0.5, 0.85, 2.18, 0.82, 1.15, 2.42, 0x1B1C26)
        // Mug.
        pen.cylinder(1.15, 0.8, r: 0.1, 1.35, 1.6, 0xFFFFFF)
    }

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

    static func chairSeat(_ pen: IsoPen) {
        let c: UInt32 = 0x2D3250
        for (dx, dy) in [(-0.45, 0.0), (0.45, 0.0), (0.0, -0.45), (0.0, 0.45)] {
            pen.line([P.plan(2.1, 1.85, 0.08), P.plan(2.1 + dx, 1.85 + dy, 0.05)], IsoPen.ink, width: 3)
        }
        pen.box(2.05, 1.8, 0.08, 2.15, 1.9, 0.6, 0x8A8FA8)
        pen.box(1.65, 1.35, 0.6, 2.55, 2.35, 0.74, c)
    }

    static func chairBack(_ pen: IsoPen) {
        pen.box(2.47, 1.8, 0.74, 2.55, 1.9, 0.95, 0x8A8FA8)
        pen.box(2.45, 1.4, 0.95, 2.62, 2.3, 1.75, 0x2D3250)
    }

    /// Wall shelf with the keepsakes on it.
    static func shelf(_ pen: IsoPen) {
        for z in [3.3, 4.5] {
            pen.box(0, 4.2, z, 0.6, 7.4, z + 0.12, HomeColors.wood)
        }
        // Lower board: trophy, gloves, can tower.
        pen.cylinder(0.3, 4.7, r: 0.12, 3.42, 3.55, 0xFFD23F)
        pen.box(0.22, 4.62, 3.55, 0.38, 4.78, 3.7, 0xFFD23F)
        pen.cylinder(0.3, 4.7, r: 0.18, 3.7, 4.0, 0xFFD23F)
        pen.ellipse(at: P.plan(0.3, 5.5, 3.62), rx: 7, ry: 5.5, Color(hex: 0xFF3B4E), line: 1.8)
        pen.ellipse(at: P.plan(0.3, 5.85, 3.62), rx: 7, ry: 5.5, Color(hex: 0xFF3B4E), line: 1.8)
        for (i, z) in [3.42, 3.66, 3.9].enumerated() {
            pen.cylinder(0.3, 6.75 - Double(i % 2) * 0.05, r: 0.1, z, z + 0.24, 0x1B1C26)
        }
        pen.line([P.plan(0.26, 6.84, 4.0), P.plan(0.34, 6.66, 3.62)], Color(hex: 0x7CFF4F), width: 1.6)
        // Upper board: running shoe, photo, books.
        pen.box(0.15, 4.75, 4.62, 0.45, 5.35, 4.75, 0xFFFFFF)
        pen.box(0.15, 4.75, 4.75, 0.45, 4.98, 4.85, 0xFF3EA5)
        pen.box(0.05, 5.8, 4.62, 0.12, 6.4, 5.05, 0xFFF6E5)
        pen.onLeftWall(x: 0.12, 5.88, 4.7, 6.32, 4.97, Color(hex: 0x7FB2FF), line: 1.2)
        for (i, c) in [UInt32(0x3A6B58), 0xFF9F43, 0x2D3250].enumerated() {
            let y = 6.7 + Double(i) * 0.18
            pen.box(0.08, y, 4.62, 0.5, y + 0.16, 5.0 - Double(i) * 0.06, c)
        }
    }

    static func posters(_ pen: IsoPen) {
        pen.onLeftWall(x: 0.02, 0.8, 2.9, 1.9, 4.5, Color(hex: 0x1B1C26), line: 2.2)
        pen.line(
            [P.plan(0.02, 1.05, 4.15), P.plan(0.02, 1.35, 3.3), P.plan(0.02, 1.65, 4.15)], Color(hex: 0xFF3EA5),
            width: 5)
        pen.onLeftWall(x: 0.02, 2.2, 3.1, 3.1, 4.4, Color(hex: 0xFFF6E5), line: 2.2)
        pen.line(
            [P.plan(0.02, 2.4, 3.6), P.plan(0.02, 2.6, 4.1), P.plan(0.02, 2.75, 3.5), P.plan(0.02, 2.9, 4.05)],
            Color(hex: 0x3A6B58), width: 3)
    }

    static func sofaBack(_ pen: IsoPen, _ c: UInt32) {
        pen.box(0, 4.4, 0, 0.7, 7.6, 1.55, c, top: tone(c, 0.18))
        // Back cushions.
        pen.box(0.55, 4.95, 0.55, 0.85, 5.95, 1.35, 0xFF3EA5)
        pen.box(0.55, 6.05, 0.55, 0.85, 6.95, 1.3, 0x7CC77F)
    }

    static func sofaArm(_ pen: IsoPen, _ c: UInt32, near: Bool) {
        let y0 = near ? 7.0 : 4.4
        pen.box(0.7, y0, 0, 2.2, y0 + 0.6, 1.0, c, top: tone(c, 0.18))
    }

    static func sofaSeat(_ pen: IsoPen, _ c: UInt32) {
        pen.box(0.7, 5.0, 0, 2.2, 7.0, 0.6, c, top: tone(c, 0.24))
        pen.line([P.plan(0.75, 6.0, 0.6), P.plan(2.2, 6.0, 0.6), P.plan(2.2, 6.0, 0.3)], tone(c, -0.35), width: 1.8)
    }

    static func table(_ pen: IsoPen) {
        for (x, y) in [(3.05, 5.15), (4.25, 5.15), (3.05, 6.15), (4.25, 6.15)] {
            pen.box(x, y, 0, x + 0.1, y + 0.1, 0.45, HomeColors.woodDark)
        }
        pen.box(3.0, 5.1, 0.45, 4.4, 6.3, 0.55, HomeColors.wood, top: tone(HomeColors.wood, 0.25))
        pen.box(3.25, 5.35, 0.55, 3.85, 5.8, 0.63, 0x3A6B58)
        pen.cylinder(4.05, 5.9, r: 0.1, 0.55, 0.8, 0x1B1C26)
    }

    static func rug(_ pen: IsoPen, _ c: UInt32) {
        pen.floor(2.6, 3.8, 6.0, 8.2, Color(hex: c), z: 0.01)
        pen.floor(2.85, 4.05, 5.75, 7.95, tone(c, 0.25), z: 0.01, line: 0)
        pen.floor(3.05, 4.25, 5.55, 7.75, Color(hex: c), z: 0.01, line: 0)
    }

    static func partition(_ pen: IsoPen, walls: UInt32) {
        pen.box(
            GridBox(x0: 6.4, y0: 0, x1: 6.6, y1: 2.2, z1: HomeGrid.wallHeight), walls, top: HomeColors.wallTop,
            left: tone(HomeColors.cut, -0.06), right: tone(walls, -0.05))
    }

    static func wardrobe(_ pen: IsoPen, owned: [HomeOutfit]) {
        let wood: UInt32 = 0x8B5A3C
        pen.box(6.8, 0, 0, 8.9, 1.3, 4.6, wood)
        // Open front: dark inside, rail, clothes, a drawer row.
        pen.onBackWall(y: 1.3, 7.0, 1.2, 8.7, 4.4, Color(hex: 0x3B2418))
        pen.line([P.plan(7.0, 1.2, 4.05), P.plan(8.7, 1.2, 4.05)], Color(hex: 0xC3C8D2), width: 2.5)
        for (i, o) in owned.prefix(5).enumerated() {
            let u = 7.12 + Double(i) * 0.31
            pen.onBackWall(y: 1.25, u, 2.5, u + 0.27, 3.95, o.base, line: 1.6)
            pen.line([P.plan(u + 0.135, 1.25, 3.95), P.plan(u + 0.135, 1.25, 4.1)], IsoPen.ink, width: 1.5)
        }
        pen.box(7.0, 0.15, 1.2, 8.7, 1.3, 1.3, 0x9C6B4C)
        pen.box(7.1, 0.3, 1.3, 7.7, 1.1, 1.75, 0xEADCC2)
        pen.onBackWall(y: 1.3, 6.85, 0.1, 8.85, 1.15, Color(hex: wood))
        pen.line([P.plan(7.6, 1.3, 0.65), P.plan(8.1, 1.3, 0.65)], IsoPen.ink, width: 3)
        // Boxes on top.
        pen.box(7.0, 0.2, 4.6, 7.8, 1.0, 5.1, 0xFF3B4E)
        pen.box(7.9, 0.25, 4.6, 8.6, 0.95, 4.95, 0x1B1C26)
    }

    static func shop(_ pen: IsoPen) {
        pen.box(9.0, 0.1, 0, 10, 1.2, 3.6, 0x1B1C26, top: Color(hex: 0x2D3250))
        // Glass with cans.
        pen.onBackWall(y: 1.2, 9.1, 1.4, 9.72, 3.4, Color(hex: 0x0D3326), line: 2)
        for row in 0..<3 {
            for col in 0..<3 {
                let u = 9.16 + Double(col) * 0.19
                let z = 1.55 + Double(row) * 0.62
                pen.onBackWall(y: 1.2, u, z, u + 0.13, z + 0.42, Color(hex: 0x1B1C26), line: 1.2)
                pen.onBackWall(y: 1.2, u + 0.02, z + 0.12, u + 0.11, z + 0.3, Color(hex: 0x7CFF4F), line: 0)
            }
        }
        // Side panel with a bolt, coin slot, tray.
        pen.onBackWall(y: 1.2, 9.78, 1.4, 9.95, 3.4, Color(hex: 0x2D3250), line: 1.6)
        pen.line(
            [P.plan(9.9, 1.2, 2.85), P.plan(9.83, 1.2, 2.45), P.plan(9.9, 1.2, 2.45), P.plan(9.83, 1.2, 2.05)],
            Color(hex: 0x7CFF4F), width: 2.4)
        pen.onBackWall(y: 1.2, 9.2, 0.35, 9.8, 0.8, Color(hex: 0x0B0C12), line: 1.6)
        pen.line([P.plan(9.1, 1.2, 3.47), P.plan(9.95, 1.2, 3.47)], Color(hex: 0x3EF0FF), width: 2)
    }

    static func bed(_ pen: IsoPen) {
        let frame: UInt32 = 0x5B3A29
        pen.box(6.6, 4.8, 0, 9.6, 5.05, 1.7, frame)
        pen.box(6.6, 5.05, 0.1, 9.6, 8.8, 0.4, frame)
        pen.box(6.7, 5.05, 0.4, 9.5, 8.7, 0.65, 0xF4F1EA)
        pen.box(6.9, 5.15, 0.65, 8.0, 5.85, 0.88, 0xFFFFFF)
        pen.box(8.15, 5.15, 0.65, 9.3, 5.85, 0.86, 0xEDE6D8)
    }

    /// The blanket, folded at the foot or pulled up over HAKU.
    static func blanket(_ pen: IsoPen, _ c: UInt32, covering: Bool) {
        if covering {
            pen.box(6.65, 6.3, 0.62, 9.55, 8.75, 0.82, c, top: tone(c, 0.12))
            pen.box(7.5, 6.6, 0.82, 8.7, 8.3, 0.96, c, top: tone(c, 0.18), line: 0)
            pen.line([P.plan(6.65, 6.3, 0.82), P.plan(9.55, 6.3, 0.82)], tone(c, 0.5), width: 3)
        } else {
            pen.box(6.65, 7.3, 0.62, 9.55, 8.75, 0.8, c, top: tone(c, 0.12))
            pen.line([P.plan(6.65, 7.9, 0.8), P.plan(9.55, 7.9, 0.8)], tone(c, -0.3), width: 1.6)
        }
    }

    static func nightstand(_ pen: IsoPen) {
        pen.box(9.0, 3.6, 0, 9.9, 4.5, 0.9, HomeColors.wood)
        pen.line([P.plan(9.1, 4.5, 0.45), P.plan(9.8, 4.5, 0.45)], tone(HomeColors.wood, -0.4), width: 1.5)
        pen.box(9.35, 3.95, 0.9, 9.55, 4.15, 1.2, 0x2D3250)
        pen.cylinder(9.45, 4.05, r: 0.25, 1.2, 1.6, 0xFFF0C8)
    }

    static func floorLamp(_ pen: IsoPen) {
        pen.cylinder(0.5, 8.4, r: 0.28, 0, 0.1, 0x1B1C26)
        pen.cylinder(0.5, 8.4, r: 0.17, 0.4, 2.8, 0xFF5A7A)
        pen.line([P.plan(0.5, 8.4, 0.1), P.plan(0.5, 8.4, 0.4)], IsoPen.ink, width: 3)
    }

    /// A pot with big leaves; the window plant and the shop's plant.
    static func plant(_ pen: IsoPen, at x: Double, _ y: Double, size: Double, pot: UInt32) {
        let r = 0.28 * size
        pen.box(x - r, y - r, 0, x + r, y + r, 0.7 * size, pot)
        let top = HomeGrid.plan(x, y, 0.7 * size)
        let s = CGFloat(size)
        let leaves: [(CGFloat, CGFloat)] = [(-26, -30), (24, -34), (-8, -52), (10, -44), (-30, -10), (30, -14)]
        for (dx, dy) in leaves {
            var leaf = Path()
            leaf.move(to: top)
            let tip = CGPoint(x: top.x + dx * s, y: top.y + dy * s)
            leaf.addQuadCurve(to: tip, control: CGPoint(x: top.x + dx * s * 0.2 - 10 * s, y: top.y + dy * s * 0.7))
            leaf.addQuadCurve(to: top, control: CGPoint(x: top.x + dx * s * 0.9 + 6 * s, y: top.y + dy * s * 0.4))
            pen.context.fill(leaf, with: .color(Color(hex: HomeColors.leaf)))
            pen.context.stroke(leaf, with: .color(IsoPen.ink), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
    }

    static func doormat(_ pen: IsoPen) {
        pen.floor(3.6, 9.05, 5.6, 9.9, Color(hex: 0x3A3D52), z: 0.01)
        pen.floor(3.8, 9.25, 5.4, 9.7, Color(hex: 0x4E5270), z: 0.01, line: 0)
    }

    // MARK: Shop items

    static func item(_ pen: IsoPen, _ item: HomeItem) {
        let s = item.spot
        switch item {
        case .plant:
            plant(pen, at: s.x, s.y, size: 1.2, pot: 0xFF3EA5)
        case .bag:
            pen.cylinder(s.x, s.y, r: 0.36, 0, 0.14, 0x2D3250)
            pen.cylinder(s.x, s.y, r: 0.26, 0.14, 1.95, 0xFF3B4E)
            for z in [0.45, 1.65] {
                pen.line(
                    [HomeGrid.plan(s.x - 0.19, s.y + 0.19, z), HomeGrid.plan(s.x + 0.19, s.y - 0.19, z)], IsoPen.ink,
                    width: 2.5)
            }
            pen.line([HomeGrid.plan(s.x, s.y, 1.95), HomeGrid.plan(s.x, s.y, 2.6)], IsoPen.ink, width: 2)
        case .cactus:
            pen.box(s.x - 0.14, s.y - 0.14, s.z, s.x + 0.14, s.y + 0.14, s.z + 0.22, 0xD9774A)
            pen.cylinder(s.x, s.y, r: 0.08, s.z + 0.22, s.z + 0.62, 0x58C25A, line: 1.8)
            pen.line(
                [HomeGrid.plan(s.x, s.y, s.z + 0.42), HomeGrid.plan(s.x - 0.16, s.y + 0.16, s.z + 0.5)],
                Color(hex: 0x58C25A), width: 5)
        case .speaker:
            pen.box(s.x - 0.3, s.y - 0.3, 0, s.x + 0.3, s.y + 0.3, 0.85, 0x1B1C26)
            pen.ellipse(at: HomeGrid.plan(s.x, s.y + 0.3, 0.55), rx: 6, ry: 6.5, Color(hex: 0x3A3D52), line: 1.8)
            pen.ellipse(at: HomeGrid.plan(s.x, s.y + 0.3, 0.55), rx: 2.5, ry: 2.5, Color(hex: 0x3EF0FF), line: 0)
            pen.ellipse(at: HomeGrid.plan(s.x, s.y + 0.3, 0.22), rx: 3.5, ry: 3.5, Color(hex: 0x3A3D52), line: 1.4)
        }
    }

    // MARK: Light

    /// Darkens the whole room for night.
    static func nightShade(_ pen: IsoPen) {
        let n = HomeGrid.size
        let h = HomeGrid.wallHeight
        let w = HomeGrid.wallThickness
        let outline = [
            P.plan(-w, n, -HomeGrid.slab), P.plan(n, n, -HomeGrid.slab), P.plan(n, -w, -HomeGrid.slab),
            P.plan(n, -w, h), P.plan(-w, -w, h), P.plan(-w, n, h),
        ]
        pen.polygon(outline, Color(hex: 0x141A3A).opacity(0.42), line: 0)
    }

    /// Sunlight through the window onto the floor.
    static func sunPatch(_ pen: IsoPen) {
        let w = window
        pen.polygon(
            [
                P.plan(w.u0 + 0.2, 0.02, 0), P.plan(w.u1 - 0.2, 0.02, 0), P.plan(w.u1 + 1.6, 3.6, 0),
                P.plan(w.u0 + 1.8, 3.6, 0),
            ], Color(hex: 0xFFE9A8).opacity(0.5), line: 0)
    }
}

/// What the desk monitor shows.
enum HomeScreen: Sendable {
    case off, code, sketch
}

#endif
