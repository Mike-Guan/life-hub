#if os(iOS) || os(macOS)
import SwiftUI

// 商店扩充 v1 §2.3: her own room items, drawn like HomeArt's pieces (thin ink lines, flat colours).
/// A room item only the second preset character's shop sells. Raw values are what follows `room.` in the shop id,
/// as in `HomeItem`.
enum KuroRoomItem: String, CaseIterable, Sendable {
    case posterCat = "poster.cat"
    case posterStars = "poster.stars"
    case clockCat = "clock.cat"
    case jar
    case mugStrawberry = "mug.strawberry"
    case mirror
    case yarn
    case plush
    case sakura
    case easel
}

/// The drawing of her room items, in plan coordinates.
enum KuroRoomArt {
    typealias P = HomeGrid

    /// Draws `item` standing at `s`; a poster hangs on the left wall with its middle at `s`.
    static func draw(_ item: KuroRoomItem, _ pen: IsoPen, at s: GridPoint) {
        switch item {
        case .posterCat: posterCat(pen, s)
        case .posterStars: posterStars(pen, s)
        case .clockCat: clockCat(pen, s)
        case .jar: jar(pen, s)
        case .mugStrawberry: mug(pen, s)
        case .mirror: mirror(pen, s)
        case .yarn: yarn(pen, s)
        case .plush: plush(pen, s)
        case .sakura: sakura(pen, s)
        case .easel: easel(pen, s)
        }
    }

    /// The boxes the drawing of `item` at `s` fills.
    static func boxes(_ item: KuroRoomItem, at s: GridPoint) -> [GridBox] {
        switch item {
        case .posterCat: [GridBox(x0: 0, y0: s.y - 0.55, x1: 0.1, y1: s.y + 0.55, z0: s.z - 0.85, z1: s.z + 0.85)]
        case .posterStars: [GridBox(x0: 0, y0: s.y - 0.6, x1: 0.1, y1: s.y + 0.6, z0: s.z - 0.8, z1: s.z + 0.8)]
        case .clockCat, .jar, .mugStrawberry, .mirror:
            [GridBox(x0: s.x - 0.25, y0: s.y - 0.25, x1: s.x + 0.25, y1: s.y + 0.25, z0: s.z, z1: s.z + 0.95)]
        case .yarn, .plush: [GridBox(x0: s.x - 0.4, y0: s.y - 0.4, x1: s.x + 0.4, y1: s.y + 0.4, z1: 1.2)]
        case .sakura: [GridBox(x0: s.x - 1, y0: s.y - 1, x1: s.x + 0.6, y1: s.y + 0.6, z1: 2.4)]
        case .easel: [GridBox(x0: s.x - 0.5, y0: s.y - 0.5, x1: s.x + 0.5, y1: s.y + 0.5, z1: 2)]
        }
    }

    // MARK: Helpers

    /// Fills `path` and strokes it in ink, or in `stroke`, with the room's line weight.
    private static func shape(
        _ pen: IsoPen, _ path: Path, _ fill: Color?, line: CGFloat = 2, stroke: Color = IsoPen.ink
    ) {
        if let fill { pen.context.fill(path, with: .color(fill)) }
        guard line > 0 else { return }
        pen.context.stroke(
            path, with: .color(stroke),
            style: StrokeStyle(lineWidth: line * IsoPen.weight, lineCap: .round, lineJoin: .round))
    }

    private static func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }

    // Each poster is drawn round a fixed middle on the left wall and moved to its slot.
    /// A point on the left wall, `u` along it and `v` up, moved from `middle` to `s`.
    private static func onWall(_ s: GridPoint, middle: (Double, Double)) -> (Double, Double) -> CGPoint {
        { u, v in P.plan(0.02, u + s.y - middle.0, v + s.z - middle.1) }
    }

    /// A rectangle on the left wall from `u0`, `v0` to `u1`, `v1`.
    private static func sheet(
        _ pen: IsoPen, _ wall: (Double, Double) -> CGPoint, _ u0: Double, _ v0: Double, _ u1: Double, _ v1: Double,
        _ fill: Color, line: CGFloat = 2.2
    ) {
        pen.polygon([wall(u0, v0), wall(u1, v0), wall(u1, v1), wall(u0, v1)], fill, line: line)
    }

    /// A four-point star round `c`, `r` from its middle to each point's base.
    private static func star(_ c: CGPoint, _ r: CGFloat) -> Path {
        polygon([
            CGPoint(x: c.x, y: c.y - 2 * r), CGPoint(x: c.x + 0.6 * r, y: c.y - 0.6 * r),
            CGPoint(x: c.x + 2 * r, y: c.y), CGPoint(x: c.x + 0.6 * r, y: c.y + 0.6 * r),
            CGPoint(x: c.x, y: c.y + 2 * r), CGPoint(x: c.x - 0.6 * r, y: c.y + 0.6 * r),
            CGPoint(x: c.x - 2 * r, y: c.y), CGPoint(x: c.x - 0.6 * r, y: c.y - 0.6 * r),
        ])
    }

    // MARK: Poster wall

    // A cat's face on a white sheet with a lilac border, pinned with a red pin.
    private static func posterCat(_ pen: IsoPen, _ s: GridPoint) {
        let wall = onWall(s, middle: (1.35, 3.65))
        sheet(pen, wall, 0.8, 2.8, 1.9, 4.5, KuroPalette.mist)
        sheet(pen, wall, 0.9, 2.9, 1.8, 4.4, .white, line: 0)
        let c = { (u: Double, v: Double) in wall(1.35 + u, 3.55 + v) }
        for side in [-1.0, 1] {
            let ear = polygon([c(0.3 * side, 0.15), c(0.26 * side, 0.52), c(0.08 * side, 0.28)])
            shape(pen, ear, KuroPalette.hair, line: 1.6)
            let inner = polygon([c(0.24 * side, 0.24), c(0.22 * side, 0.42), c(0.12 * side, 0.3)])
            shape(pen, inner, KuroPalette.pink, line: 0)
        }
        let face = (0..<24).map { i in
            let a = Double(i) / 24 * 2 * .pi
            return c(0.33 * cos(a), 0.28 * sin(a))
        }
        shape(pen, polygon(face), KuroPalette.hair, line: 1.8)
        for side in [-1.0, 1] {
            let eye = c(0.12 * side, 0.04)
            pen.ellipse(at: eye, rx: 2.6, ry: 3, KuroPalette.gold, line: 0)
            pen.ellipse(at: eye, rx: 0.8, ry: 2.2, IsoPen.ink, line: 0)
            for dv in [-0.06, -0.12] {
                pen.line(
                    [c(0.34 * side, dv), c(0.42 * side, dv + (dv < -0.1 ? -0.04 : 0.04))], KuroPalette.hair, width: 1)
            }
        }
        pen.ellipse(at: c(0, -0.08), rx: 1.4, ry: 1, KuroPalette.pink, line: 0)
        pen.line([wall(1.0, 3.05), wall(1.7, 3.05)], KuroPalette.lavender, width: 2.4)
        pen.ellipse(at: wall(1.35, 4.42), rx: 1.6, ry: 1.6, KuroPalette.red, line: 0.8)
    }

    // A night sky: a crescent moon, small stars and a lilac hill line.
    private static func posterStars(_ pen: IsoPen, _ s: GridPoint) {
        let wall = onWall(s, middle: (2.6, 3.7))
        sheet(pen, wall, 2.0, 2.9, 3.2, 4.5, KuroPalette.navy)
        let moon = wall(2.85, 4.05)
        pen.ellipse(at: moon, rx: 6.5, ry: 7, KuroPalette.yellow, line: 0)
        pen.ellipse(at: CGPoint(x: moon.x + 2.8, y: moon.y - 2), rx: 5.6, ry: 6, KuroPalette.navy, line: 0)
        let stars: [(Double, Double, CGFloat)] = [
            (2.25, 4.25, 1.6), (2.5, 3.7, 2.2), (2.95, 3.35, 1.4), (2.3, 3.15, 1.2), (3.05, 3.75, 1), (2.7, 4.35, 1),
        ]
        for (u, v, r) in stars { shape(pen, star(wall(u, v), r), KuroPalette.goldStrings, line: 0) }
        pen.line([wall(2.1, 3.0), wall(2.4, 3.12), wall(2.7, 3.02), wall(3.1, 3.1)], KuroPalette.lavender, width: 1.2)
        pen.ellipse(at: wall(2.6, 4.42), rx: 1.6, ry: 1.6, KuroPalette.gold, line: 0.8)
    }

    // MARK: Desk

    // A round violet alarm clock with cat ears, on two feet.
    private static func clockCat(_ pen: IsoPen, _ s: GridPoint) {
        let c = P.plan(s.x, s.y, s.z + 0.36)
        pen.line([P.plan(s.x, s.y - 0.12, s.z), P.plan(s.x, s.y - 0.04, s.z + 0.12)], width: 2.4)
        pen.line([P.plan(s.x, s.y + 0.12, s.z), P.plan(s.x, s.y + 0.04, s.z + 0.12)], width: 2.4)
        for side in [-1.0, 1] {
            let ear = polygon([
                CGPoint(x: c.x + 9 * side, y: c.y - 7), CGPoint(x: c.x + 10 * side, y: c.y - 16),
                CGPoint(x: c.x + 3 * side, y: c.y - 10),
            ])
            shape(pen, ear, KuroPalette.violet, line: 1.8)
        }
        pen.ellipse(at: CGPoint(x: c.x, y: c.y + 0.6), rx: 11.5, ry: 11, KuroPalette.violet)
        pen.ellipse(at: c, rx: 8.3, ry: 8, .white, line: 1.4)
        for i in 0..<12 {
            let a = Double(i) / 12 * 2 * .pi
            let tick = CGPoint(x: c.x + 6.6 * CGFloat(cos(a)), y: c.y + 6.4 * CGFloat(sin(a)))
            pen.ellipse(at: tick, rx: 0.45, ry: 0.45, KuroPalette.lavender, line: 0)
        }
        pen.line([c, CGPoint(x: c.x, y: c.y - 5.5)], width: 1.6)
        pen.line([c, CGPoint(x: c.x + 3.8, y: c.y + 1.2)], width: 1.6)
        pen.ellipse(at: c, rx: 1, ry: 1, KuroPalette.pink, line: 0)
    }

    // A little aroma jar: lilac glass, a gold lid and a label. No flame.
    private static func jar(_ pen: IsoPen, _ s: GridPoint) {
        pen.cylinder(s.x, s.y, r: 0.17, s.z, s.z + 0.36, 0xC9B8FF, line: 1.6)
        pen.cylinder(s.x, s.y, r: 0.18, s.z + 0.36, s.z + 0.44, 0xFFD23F, line: 1.6)
        let label = P.plan(s.x + 0.17, s.y, s.z + 0.24)
        shape(pen, Path(CGRect(x: label.x - 7, y: label.y - 3, width: 9, height: 6)), .white, line: 1.1)
        pen.line([CGPoint(x: label.x - 5, y: label.y), CGPoint(x: label.x, y: label.y)], KuroPalette.pink, width: 1.2)
        let shine = P.plan(s.x, s.y, s.z + 0.3)
        pen.line(
            [CGPoint(x: shine.x - 5, y: shine.y - 1), CGPoint(x: shine.x - 5, y: shine.y + 4)],
            Color.white.opacity(0.7), width: 1.6)
    }

    // Strawberry milk: a pink mug with two strawberries and a red straw.
    private static func mug(_ pen: IsoPen, _ s: GridPoint) {
        pen.cylinder(s.x, s.y, r: 0.16, s.z, s.z + 0.4, 0xFFD1DC, line: 1.6)
        let top = P.plan(s.x, s.y, s.z + 0.4)
        pen.ellipse(at: top, rx: 6, ry: 3, KuroPalette.blanket, line: 1.2)
        pen.line([CGPoint(x: top.x + 1, y: top.y), CGPoint(x: top.x + 6, y: top.y - 11)], KuroPalette.red, width: 2.2)
        let side = P.plan(s.x, s.y, s.z + 0.22)
        var handle = Path()
        handle.move(to: CGPoint(x: side.x - 6.6, y: side.y - 6))
        handle.addQuadCurve(
            to: CGPoint(x: side.x - 13.6, y: side.y - 1), control: CGPoint(x: side.x - 13.6, y: side.y - 7))
        handle.addQuadCurve(
            to: CGPoint(x: side.x - 6.6, y: side.y + 3), control: CGPoint(x: side.x - 13.6, y: side.y + 4))
        shape(pen, handle, nil, line: 2.4)
        shape(pen, handle, nil, line: 1.2, stroke: KuroPalette.petal)
        for (dy, dz) in [(-0.02, 0.12), (0.1, 0.24)] {
            let berry = P.plan(s.x + 0.08, s.y + 0.1 + dy, s.z + dz)
            var fruit = Path()
            fruit.move(to: CGPoint(x: berry.x - 2.4, y: berry.y - 1.5))
            fruit.addQuadCurve(
                to: CGPoint(x: berry.x + 2.4, y: berry.y - 1.5), control: CGPoint(x: berry.x, y: berry.y + 4.5))
            fruit.closeSubpath()
            shape(pen, fruit, KuroPalette.red, line: 0.9)
            pen.line(
                [CGPoint(x: berry.x - 1.6, y: berry.y - 2.2), CGPoint(x: berry.x + 1.6, y: berry.y - 2.2)],
                KuroPalette.leaf, width: 1.4)
        }
    }

    // A round vanity mirror on a pink stand.
    private static func mirror(_ pen: IsoPen, _ s: GridPoint) {
        pen.cylinder(s.x, s.y, r: 0.16, s.z, s.z + 0.05, 0xFF8FA3, line: 1.4)
        let stem = [P.plan(s.x, s.y, s.z + 0.05), P.plan(s.x, s.y, s.z + 0.32)]
        pen.line(stem, width: 2.6)
        pen.line(stem, KuroPalette.pink, width: 1.4)
        let c = P.plan(s.x, s.y, s.z + 0.62)
        pen.ellipse(at: c, rx: 10, ry: 11, KuroPalette.pink, line: 1.8)
        pen.ellipse(at: c, rx: 7.4, ry: 8.4, Color(hex: 0xDDEBFF), line: 1.2)
        pen.line([CGPoint(x: c.x - 4, y: c.y + 2), CGPoint(x: c.x + 1, y: c.y - 5)], .white, width: 1.6)
        pen.line([CGPoint(x: c.x - 1.5, y: c.y + 4.5), CGPoint(x: c.x + 3, y: c.y - 1.5)], .white, width: 1.1)
    }

    // MARK: Sofa side

    // A woven basket with three balls of yarn and two needles.
    private static func yarn(_ pen: IsoPen, _ s: GridPoint) {
        let basket: UInt32 = 0xD9A066
        pen.contact(s.x - 0.4, s.y - 0.4, s.x + 0.4, s.y + 0.4)
        pen.cylinder(s.x, s.y, r: 0.38, 0, 0.42, basket, line: 1.8)
        let rx = CGFloat(0.38) * HomeGrid.unit * 1.22
        for z in [0.14, 0.28] {
            let a = P.plan(s.x, s.y, z)
            var weave = Path()
            weave.move(to: CGPoint(x: a.x - rx, y: a.y))
            weave.addQuadCurve(to: CGPoint(x: a.x + rx, y: a.y), control: CGPoint(x: a.x, y: a.y + rx * 0.55))
            shape(pen, weave, nil, line: 1.1, stroke: tone(basket, -0.4))
        }
        let balls: [(Double, Double, UInt32, CGFloat)] = [
            (-0.12, 0.05, 0x7B5CFF, 8), (0.14, -0.05, 0xFF8FA3, 7.5), (0.02, 0.16, 0xF2E8FF, 7),
        ]
        for (dx, dy, c, r) in balls {
            let q = P.plan(s.x + dx, s.y + dy, 0.5)
            pen.ellipse(at: q, rx: r, ry: r * 0.92, Color(hex: c), line: 1.6)
            var strands = Path()
            strands.move(to: CGPoint(x: q.x - r * 0.7, y: q.y - r * 0.2))
            strands.addQuadCurve(
                to: CGPoint(x: q.x + r * 0.7, y: q.y + r * 0.1), control: CGPoint(x: q.x, y: q.y - r * 0.9))
            strands.move(to: CGPoint(x: q.x - r * 0.5, y: q.y + r * 0.4))
            strands.addQuadCurve(
                to: CGPoint(x: q.x + r * 0.6, y: q.y + r * 0.5), control: CGPoint(x: q.x + r * 0.1, y: q.y - r * 0.2))
            shape(pen, strands, nil, line: 1, stroke: tone(c, -0.35))
        }
        let n = P.plan(s.x + 0.05, s.y, 0.62)
        for dx: CGFloat in [0, 4] {
            let tip = CGPoint(x: n.x + 10 + dx, y: n.y - 14 + dx / 2)
            pen.line([CGPoint(x: n.x - 3 + dx, y: n.y + 6), tip], KuroPalette.gold, width: 2)
            pen.ellipse(at: tip, rx: 1.6, ry: 1.6, KuroPalette.red, line: 0.8)
        }
    }

    // A black cat plush sitting up, with pink inner ears and a red bow on its collar.
    private static func plush(_ pen: IsoPen, _ s: GridPoint) {
        pen.contact(s.x - 0.3, s.y - 0.3, s.x + 0.3, s.y + 0.3)
        let body = P.plan(s.x, s.y, 0.3)
        pen.ellipse(at: body, rx: 11, ry: 10, KuroPalette.hair)
        let root = P.plan(s.x - 0.2, s.y + 0.25, 0.1)
        var tail = Path()
        tail.move(to: root)
        tail.addQuadCurve(to: CGPoint(x: root.x - 7, y: root.y - 13), control: CGPoint(x: root.x - 9, y: root.y - 3))
        shape(pen, tail, nil, line: 4.6)
        shape(pen, tail, nil, line: 2.6, stroke: KuroPalette.hair)
        for side in [-1.0, 1] {
            pen.ellipse(at: CGPoint(x: body.x + 5 * side, y: body.y + 8), rx: 4, ry: 2.6, KuroPalette.hair, line: 1.6)
        }
        let head = P.plan(s.x, s.y, 0.88)
        for side in [-1.0, 1] {
            let ear = polygon([
                CGPoint(x: head.x + 6 * side, y: head.y - 7), CGPoint(x: head.x + 11 * side, y: head.y - 17),
                CGPoint(x: head.x + 12 * side, y: head.y - 4),
            ])
            shape(pen, ear, KuroPalette.hair, line: 1.8)
            let inner = polygon([
                CGPoint(x: head.x + 8 * side, y: head.y - 8), CGPoint(x: head.x + 10.5 * side, y: head.y - 13.5),
                CGPoint(x: head.x + 10.8 * side, y: head.y - 7),
            ])
            shape(pen, inner, KuroPalette.pink, line: 0)
        }
        pen.ellipse(at: head, rx: 12, ry: 10, KuroPalette.hair)
        for side in [-1.0, 1] {
            let eye = CGPoint(x: head.x + 4.6 * side, y: head.y)
            pen.ellipse(at: eye, rx: 2.2, ry: 2.6, KuroPalette.gold, line: 0)
            pen.ellipse(at: eye, rx: 0.7, ry: 2, IsoPen.ink, line: 0)
        }
        var mouth = Path()
        mouth.move(to: CGPoint(x: head.x - 1.6, y: head.y + 4))
        mouth.addQuadCurve(to: CGPoint(x: head.x, y: head.y + 4), control: CGPoint(x: head.x - 0.8, y: head.y + 5.6))
        mouth.addQuadCurve(
            to: CGPoint(x: head.x + 1.6, y: head.y + 4), control: CGPoint(x: head.x + 0.8, y: head.y + 5.6))
        shape(pen, mouth, nil, line: 1, stroke: .white)
        var collar = Path()
        collar.move(to: CGPoint(x: head.x - 9, y: head.y + 9))
        collar.addQuadCurve(to: CGPoint(x: head.x + 9, y: head.y + 9), control: CGPoint(x: head.x, y: head.y + 13))
        shape(pen, collar, nil, line: 2.4, stroke: KuroPalette.red)
        let knot = CGPoint(x: head.x + 3, y: head.y + 11)
        for side: CGFloat in [-1, 1] {
            let wing = polygon([
                knot, CGPoint(x: knot.x + 3.4 * side, y: knot.y - 3), CGPoint(x: knot.x + 3.4 * side, y: knot.y + 3),
            ])
            shape(pen, wing, KuroPalette.red, line: 1)
        }
    }

    // MARK: Corner

    // A sakura tree in a mist-coloured pot painted with petals, and a petal on the floor.
    private static func sakura(_ pen: IsoPen, _ s: GridPoint) {
        pen.contact(s.x - 0.35, s.y - 0.35, s.x + 0.35, s.y + 0.35)
        pen.box(s.x - 0.32, s.y - 0.32, 0, s.x + 0.32, s.y + 0.32, 0.7, 0xF2E8FF)
        // Three petals painted on the pot's front.
        for (dx, z) in [(-0.18, 0.45), (0.0, 0.3), (0.16, 0.5)] {
            pen.ellipse(at: P.plan(s.x + dx, s.y + 0.32, z), rx: 2.2, ry: 1.8, KuroPalette.sakura, line: 0.8)
        }
        let top = P.plan(s.x, s.y, 0.7)
        let soil = CGFloat(0.32) * HomeGrid.unit
        pen.ellipse(at: top, rx: soil * 0.95, ry: soil * 0.45, Color(hex: 0x5B3A29), line: 0)
        var trunk = Path()
        trunk.move(to: top)
        trunk.addCurve(
            to: CGPoint(x: top.x + 2, y: top.y - 48), control1: CGPoint(x: top.x - 2, y: top.y - 20),
            control2: CGPoint(x: top.x + 6, y: top.y - 30))
        trunk.move(to: CGPoint(x: top.x + 1, y: top.y - 26))
        trunk.addQuadCurve(to: CGPoint(x: top.x - 14, y: top.y - 44), control: CGPoint(x: top.x - 10, y: top.y - 34))
        trunk.move(to: CGPoint(x: top.x + 3, y: top.y - 36))
        trunk.addQuadCurve(to: CGPoint(x: top.x + 16, y: top.y - 52), control: CGPoint(x: top.x + 12, y: top.y - 42))
        shape(pen, trunk, nil, line: 4.4, stroke: Color(hex: HomeColors.woodDark))
        let blossoms: [(CGFloat, CGFloat, CGFloat)] = [
            (-16, -48, 12), (2, -58, 14), (18, -54, 12), (-6, -42, 10), (12, -42, 9), (-22, -38, 8),
        ]
        for (dx, dy, r) in blossoms {
            pen.ellipse(at: CGPoint(x: top.x + dx, y: top.y + dy), rx: r, ry: r * 0.82, KuroPalette.sakura, line: 1.8)
        }
        let petals: [(CGFloat, CGFloat)] = [
            (-12, -52), (6, -62), (16, -50), (-2, -46), (-20, -40), (10, -44), (0, -56),
        ]
        for (dx, dy) in petals {
            let q = CGPoint(x: top.x + dx, y: top.y + dy)
            pen.ellipse(at: q, rx: 2, ry: 2, KuroPalette.petal, line: 0)
            pen.ellipse(at: q, rx: 0.7, ry: 0.7, KuroPalette.pink, line: 0)
        }
        pen.ellipse(at: P.plan(s.x + 0.5, s.y + 0.6, 0.01), rx: 2.2, ry: 1.2, KuroPalette.petal, line: 0.6)
    }

    // A small A-frame easel holding a canvas: a sakura tree, a sun and flowers in the grass.
    private static func easel(_ pen: IsoPen, _ s: GridPoint) {
        pen.contact(s.x - 0.4, s.y - 0.25, s.x + 0.4, s.y + 0.25)
        let legs: [((Double, Double), (Double, Double), Double)] = [
            ((s.x - 0.45, s.y - 0.45), (s.x, s.y), 1.9),
            ((s.x + 0.35, s.y - 0.35), (s.x + 0.05, s.y - 0.05), 2.0),
            ((s.x - 0.35, s.y + 0.35), (s.x - 0.05, s.y + 0.05), 2.0),
        ]
        for (foot, head, z) in legs {
            let leg = [P.plan(foot.0, foot.1, 0), P.plan(head.0, head.1, z)]
            pen.line(leg, width: 4.6)
            pen.line(leg, Color(hex: HomeColors.wood), width: 2.6)
        }
        // The canvas faces the room; the ledge it stands on runs along its bottom edge.
        let c = { (u: Double, v: Double) in P.plan(s.x + 0.12 + u * 0.7071, s.y + 0.12 - u * 0.7071, v) }
        let ledge = [c(-0.58, 0.72), c(0.58, 0.72), c(0.58, 0.84), c(-0.58, 0.84)]
        pen.polygon(ledge, Color(hex: HomeColors.wood), line: 1.6)
        pen.polygon([c(-0.5, 0.84), c(0.5, 0.84), c(0.5, 1.85), c(-0.5, 1.85)], .white, line: 2)
        pen.polygon([c(-0.44, 0.88), c(0.44, 0.88), c(0.44, 1.25), c(-0.44, 1.25)], Color(hex: 0xBFEBD3), line: 0)
        pen.polygon([c(-0.44, 1.25), c(0.44, 1.25), c(0.44, 1.79), c(-0.44, 1.79)], Color(hex: 0xDDEBFF), line: 0)
        pen.ellipse(at: c(0.24, 1.58), rx: 4.5, ry: 4.5, KuroPalette.yellow, line: 0)
        let tree = c(-0.18, 1.2)
        pen.line([tree, CGPoint(x: tree.x, y: tree.y - 9)], Color(hex: HomeColors.woodDark), width: 2)
        pen.ellipse(at: CGPoint(x: tree.x, y: tree.y - 12), rx: 7, ry: 5.5, KuroPalette.sakura, line: 0)
        for (u, v) in [(-0.3, 0.98), (0.04, 0.95), (0.32, 1.0)] {
            pen.ellipse(at: c(u, v), rx: 1.8, ry: 1.8, KuroPalette.pink, line: 0)
            pen.ellipse(at: c(u, v), rx: 0.6, ry: 0.6, KuroPalette.yellow, line: 0)
        }
    }
}
#endif
