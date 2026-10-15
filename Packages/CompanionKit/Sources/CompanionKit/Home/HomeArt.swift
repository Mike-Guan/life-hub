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

    /// A rectangle on the back wall plane y = `y`, from x `u0` to `u1` and z `v0` to `v1`.
    func onBackWall(
        y: Double = 0, _ u0: Double, _ v0: Double, _ u1: Double, _ v1: Double, _ fill: Color, line: CGFloat = 2.2
    ) {
        let p = { (x: Double, y: Double, z: Double) in HomeGrid.plan(x, y, z) }
        polygon([p(u0, y, v0), p(u1, y, v0), p(u1, y, v1), p(u0, y, v1)], fill, line: line)
    }

    func ellipse(at c: CGPoint, rx: CGFloat, ry: CGFloat, _ fill: Color, line: CGFloat = 2) {
        let path = Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: 2 * rx, height: 2 * ry))
        context.fill(path, with: .color(fill))
        if line > 0 { context.stroke(path, with: .color(Self.ink), lineWidth: line) }
    }

}

/// What the code draws over the rendered room: the sky, the monitor's screen and the clothes in the wardrobe.
enum HomeArt {
    typealias P = HomeGrid

    // MARK: Window

    /// The window hole in the back wall, as render_room.py cuts it.
    static let window = (u0: 1.0, u1: 3.6, z0: 2.1, z1: 4.5)

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
                startPoint: P.plan(2.3, 0, w.z1), endPoint: P.plan(2.3, 0, w.z0)))
        let sub = IsoPen(context: c)
        if night {
            sub.ellipse(at: P.plan(3.0, 0, 4.0), rx: 9, ry: 9, Color(hex: 0xFFF3C4), line: 0)
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

    // MARK: Desk

    /// The plan rectangle the screen is drawn in.
    static let screenRect = HomeGrid.bounds(
        [GridBox(x0: 0.36, y0: 1.2, x1: 0.38, y1: 2.8, z0: 1.65, z1: 2.52)], margin: 3)

    /// The monitor's screen, facing HAKU's chair.
    static func screen(_ pen: IsoPen, content: HomeScreen) {
        let quad = [
            P.plan(0.37, 1.25, 1.7), P.plan(0.37, 2.75, 1.7), P.plan(0.37, 2.75, 2.48), P.plan(0.37, 1.25, 2.48),
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
            pen.line([P.plan(0.37, 1.5, 2.3), P.plan(0.37, 1.9, 2.4)], Color.white.opacity(0.18), width: 3)
        case .code:
            for (i, z) in [2.33, 2.2, 2.07, 1.94, 1.81].enumerated() {
                let indent = [0, 0.15, 0.15, 0.3, 0][i]
                let len = [0.6, 0.8, 0.5, 0.7, 0.4][i]
                pen.line(
                    [P.plan(0.37, 1.4 + indent, z), P.plan(0.37, 1.4 + indent + len, z)],
                    i == 2 ? Color(hex: 0xFF3EA5) : Color(hex: 0x3EF0FF), width: 2.4)
            }
        case .sketch:
            pen.line(
                [P.plan(0.37, 1.45, 1.9), P.plan(0.37, 1.8, 2.25), P.plan(0.37, 2.1, 2.0), P.plan(0.37, 2.5, 2.35)],
                Color(hex: 0xFFD23F), width: 2.6)
            pen.ellipse(at: P.plan(0.37, 2.35, 1.85), rx: 5, ry: 4, Color(hex: 0xFF8FC8), line: 1.5)
        }
    }

    // MARK: Wardrobe

    /// The owned tops hanging on the rail in the wardrobe's open alcove.
    static func clothes(_ pen: IsoPen, owned: [HomeOutfit]) {
        // The render's alcove is a dark panel at y = 1.32; the rail and tops sit just in front of it.
        let y = 1.34
        pen.line([P.plan(7.0, y, 4.05), P.plan(8.7, y, 4.05)], Color(hex: 0xC3C8D2), width: 2.5)
        for (i, o) in owned.prefix(5).enumerated() {
            let u = 7.12 + Double(i) * 0.31
            pen.onBackWall(y: y, u, 2.55, u + 0.27, 3.95, o.base, line: 1.2)
            pen.onBackWall(y: y, u, 2.55, u + 0.27, 2.75, Color.black.opacity(0.15), line: 0)
            pen.line([P.plan(u + 0.135, y, 3.95), P.plan(u + 0.135, y, 4.05)], Color(hex: 0xC3C8D2), width: 1.5)
        }
    }
}

/// What the desk monitor shows.
enum HomeScreen: Sendable {
    case off, code, sketch
}

#endif
