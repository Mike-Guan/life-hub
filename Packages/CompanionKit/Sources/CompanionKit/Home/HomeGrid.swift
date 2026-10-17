import CoreGraphics
import Foundation

// Issue #485: the home prototype. The numbers in this file are the room's layout table; the shipping
// home copies them, not the prototype's drawing code.

/// A point on the room's isometric grid, in cells: x runs along the back wall, y along the left wall, z up.
struct GridPoint: Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double = 0

    /// The distance to `other` on the floor, in cells.
    func distance(to other: GridPoint) -> Double {
        hypot(other.x - x, other.y - y)
    }
}

/// An axis-aligned box on the grid, in cells.
struct GridBox: Equatable, Sendable {
    var x0: Double
    var y0: Double
    var x1: Double
    var y1: Double
    var z0: Double = 0
    var z1: Double

    /// Whether the floor point lies inside the box's footprint.
    func covers(_ p: GridPoint) -> Bool {
        p.x > x0 && p.x < x1 && p.y > y0 && p.y < y1
    }
}

/// The isometric projection of the home room.
enum HomeGrid {
    /// Cells along each side of the floor.
    static let size = 10.0
    static let wallHeight = 6.2
    static let wallThickness = 0.4
    static let slab = 0.5
    /// Points per cell.
    static let unit: CGFloat = 34
    /// Where grid point (0, 0, 0) lands, in plan coordinates.
    static let origin = CGPoint(x: 440, y: 240)
    /// The part of the plan the room is drawn in. Plan coordinates have y pointing down.
    static let canvas = CGRect(x: 124, y: 4, width: 632, height: 604)
    /// The smallest tap target on screen, in points.
    static let minTap: CGFloat = 44

    private static let across = CGFloat(cos(Double.pi / 6)) * unit
    private static let down = 0.5 * unit

    /// Plan coordinates of a grid point.
    static func plan(_ x: Double, _ y: Double, _ z: Double = 0) -> CGPoint {
        CGPoint(
            x: origin.x + CGFloat(x - y) * across,
            y: origin.y + CGFloat(x + y) * down - CGFloat(z) * unit
        )
    }

    /// Plan coordinates of a grid point.
    static func plan(_ p: GridPoint) -> CGPoint {
        plan(p.x, p.y, p.z)
    }

    /// The floor point under a plan point.
    static func floor(at p: CGPoint) -> GridPoint {
        let a = Double((p.x - origin.x) / across)
        let b = Double((p.y - origin.y) / down)
        return GridPoint(x: (a + b) / 2, y: (b - a) / 2)
    }

    /// Scene coordinates (y up, origin at the canvas's bottom left) of a plan point.
    static func scene(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x - canvas.minX, y: canvas.maxY - p.y)
    }

    /// Plan coordinates of a scene point.
    static func plan(scene p: CGPoint) -> CGPoint {
        CGPoint(x: p.x + canvas.minX, y: canvas.maxY - p.y)
    }

    /// The box's outline as the camera sees it, a hexagon in plan coordinates.
    static func silhouette(_ b: GridBox) -> [CGPoint] {
        [
            plan(b.x0, b.y1, b.z0), plan(b.x1, b.y1, b.z0), plan(b.x1, b.y0, b.z0),
            plan(b.x1, b.y0, b.z1), plan(b.x0, b.y0, b.z1), plan(b.x0, b.y1, b.z1),
        ]
    }

    /// The plan rectangle that holds the box's drawing.
    static func bounds(_ boxes: [GridBox], margin: CGFloat = 6) -> CGRect {
        boxes.flatMap(silhouette).reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
            .insetBy(dx: -margin, dy: -margin)
    }

    /// Whether `p` lies inside the polygon.
    static func contains(_ polygon: [CGPoint], _ p: CGPoint) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in polygon.indices {
            let a = polygon[i]
            let b = polygon[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    /// Where HAKU stands while walking, drawn in front of furniture with a lower depth.
    static func walkingDepth(_ p: GridPoint) -> Double {
        p.x + p.y + 0.05
    }
}

/// What a tap or a drop in the room points at.
enum HomeHotspot: String, CaseIterable, Sendable {
    case haku
    case desk
    case sofa
    case bed
    case wardrobe
    case shop
    case shelf
    case window
    case bag
    case bench
    case exit
}

/// A piece of the room the scene draws as its own sprite.
enum HomePiece: String, CaseIterable, Sendable {
    case desk, chairSeat, chairBack, shelf, posters
    case sofaBack, sofaFarArm, sofaSeat, sofaNearArm, table, rug
    case wardrobe, shop, bed, blanket, nightstand, floorLamp, doormat

    /// The boxes the piece's drawing fills.
    var boxes: [GridBox] {
        switch self {
        case .desk: [GridBox(x0: 0, y0: 0.4, x1: 1.5, y1: 3.4, z1: 2.7)]
        case .chairSeat: [GridBox(x0: 1.6, y0: 1.3, x1: 2.6, y1: 2.4, z1: 0.75)]
        case .chairBack: [GridBox(x0: 2.45, y0: 1.35, x1: 2.65, y1: 2.35, z0: 0.5, z1: 1.75)]
        case .shelf: [GridBox(x0: 0, y0: 4.2, x1: 0.6, y1: 7.4, z0: 3.2, z1: 5.3)]
        case .posters: [GridBox(x0: 0, y0: 0.6, x1: 0.05, y1: 3.3, z0: 2.6, z1: 4.8)]
        case .sofaBack: [GridBox(x0: 0, y0: 4.4, x1: 0.7, y1: 7.6, z1: 1.55)]
        case .sofaFarArm: [GridBox(x0: 0.7, y0: 4.4, x1: 2.2, y1: 5.0, z1: 1.0)]
        case .sofaSeat: [GridBox(x0: 0.7, y0: 5.0, x1: 2.2, y1: 7.0, z1: 1.1)]
        case .sofaNearArm: [GridBox(x0: 0.7, y0: 7.0, x1: 2.2, y1: 7.6, z1: 1.0)]
        case .table: [GridBox(x0: 3.0, y0: 5.1, x1: 4.4, y1: 6.3, z1: 1.0)]
        case .rug: [GridBox(x0: 2.6, y0: 3.8, x1: 6.0, y1: 8.2, z1: 0)]
        case .wardrobe: [GridBox(x0: 6.8, y0: 0, x1: 8.9, y1: 1.3, z1: 4.9)]
        case .shop: [GridBox(x0: 9.0, y0: 0.1, x1: 10, y1: 1.2, z1: 3.8)]
        case .bed: [GridBox(x0: 6.6, y0: 4.8, x1: 9.6, y1: 8.8, z1: 1.7)]
        case .blanket: [GridBox(x0: 6.55, y0: 6.0, x1: 9.65, y1: 8.85, z1: 1.0)]
        case .nightstand: [GridBox(x0: 9.0, y0: 3.6, x1: 9.9, y1: 4.5, z1: 2.0)]
        case .floorLamp: [GridBox(x0: 0.2, y0: 8.1, x1: 0.8, y1: 8.7, z1: 3.0)]
        case .doormat: [GridBox(x0: 3.6, y0: 9.0, x1: 5.6, y1: 10, z1: 0.05)]
        }
    }

    /// Back to front: a piece with a larger depth is drawn over one with a smaller depth.
    var depth: Double {
        switch self {
        case .rug, .doormat: -1
        case .posters, .shelf: 0.5
        case .desk: 2.6
        case .chairSeat: 3.9
        case .chairBack: 4.6
        case .sofaBack: 6.4
        case .sofaFarArm: 6.6
        case .sofaSeat: 7.3
        case .sofaNearArm: 9.0
        case .table: 9.4
        case .wardrobe: 8.5
        case .shop: 10.1
        case .bed: 13.2
        case .blanket: 15.0
        case .nightstand: 13.4
        case .floorLamp: 8.9
        }
    }

    /// Whether HAKU walks around the piece.
    var blocksWalking: Bool {
        switch self {
        case .shelf, .posters, .rug, .doormat, .blanket: false
        default: true
        }
    }

    /// What tapping the piece points at, or `nil` when it does nothing.
    var hotspot: HomeHotspot? {
        switch self {
        case .desk, .chairSeat, .chairBack: .desk
        case .sofaBack, .sofaFarArm, .sofaSeat, .sofaNearArm: .sofa
        case .bed, .blanket: .bed
        case .wardrobe: .wardrobe
        case .shop: .shop
        case .shelf: .shelf
        case .doormat: .exit
        default: nil
        }
    }
}

// PM 家 区域规划 v0 (Mike 2026-10-17: the room is split into zones, each holding items the user picks).
/// An area of the room that holds items.
enum HomeZone: String, CaseIterable, Sendable {
    case furniture, sportFloor, sportWall, shelf, desk, sofaSide, corner

    /// The floor or wall the zone takes up; furniture has none of its own.
    var box: GridBox? {
        switch self {
        case .furniture: nil
        case .sportFloor: GridBox(x0: 3.4, y0: 0.1, x1: 6.4, y1: 3.6, z1: 2.1)
        case .sportWall: GridBox(x0: 3.8, y0: 0, x1: 5.6, y1: 0.4, z0: 2.4, z1: 4.8)
        case .shelf: GridBox(x0: 0, y0: 4.2, x1: 0.6, y1: 7.4, z0: 3.2, z1: 5.3)
        case .desk: GridBox(x0: 0, y0: 0.4, x1: 1.5, y1: 3.4, z0: 1.36, z1: 2.4)
        case .sofaSide: GridBox(x0: 2.3, y0: 8.2, x1: 2.9, y1: 8.8, z1: 1)
        case .corner: GridBox(x0: 0.9, y0: 8.7, x1: 2.1, y1: 9.9, z1: 2.6)
        }
    }

    /// Where the zone's items stand or hang, one per slot; the shelf fills itself with keepsakes.
    var slots: [GridPoint] {
        switch self {
        case .furniture, .shelf: []
        case .sportFloor: [GridPoint(x: 4.55, y: 2.0)]
        case .sportWall: [GridPoint(x: 4.4, y: 0.15, z: 3.4), GridPoint(x: 5.3, y: 0.15, z: 3.4)]
        case .desk: [GridPoint(x: 0.6, y: 3.0, z: 1.36), GridPoint(x: 0.6, y: 0.9, z: 1.36)]
        case .sofaSide: [GridPoint(x: 2.6, y: 8.5)]
        case .corner: [GridPoint(x: 1.5, y: 9.3)]
        }
    }
}

/// An item from the shop that stands in the room.
enum HomeItem: String, CaseIterable, Sendable {
    case plant, bag, cactus, speaker
    // The sports corner: gloves, racket and snowboard hang on the back wall, the bench stands under them.
    case gloves, racket, snowboard, bench

    /// The room item a shop catalog id names, such as `room.bench` or `haku.weekly.room.cactus`.
    init?(shopID: String) {
        guard let range = shopID.range(of: "room."), range.upperBound < shopID.endIndex else { return nil }
        self.init(rawValue: String(shopID[range.upperBound...]))
    }

    /// The zone the item goes in.
    var zone: HomeZone {
        switch self {
        case .plant: .corner
        case .bag, .bench: .sportFloor
        case .cactus: .desk
        case .speaker: .sofaSide
        case .gloves, .racket, .snowboard: .sportWall
        }
    }

    /// Where the item stands, or hangs.
    // Wall items stay left of x 5.5: further right the wardrobe's side hides them.
    var spot: GridPoint {
        switch self {
        case .plant: GridPoint(x: 1.5, y: 9.3)
        case .bag: GridPoint(x: 5.9, y: 3.1)
        case .cactus: GridPoint(x: 0.6, y: 3.0, z: 1.36)
        case .speaker: GridPoint(x: 2.6, y: 8.5)
        case .gloves: GridPoint(x: 4.9, y: 0.15, z: 3.4)
        case .racket: GridPoint(x: 5.25, y: 0.1, z: 3.3)
        case .snowboard: GridPoint(x: 5.3, y: 0.1)
        case .bench: GridPoint(x: 4.55, y: 2.0)
        }
    }

    /// The floor the item takes up, or `nil` when it hangs on the wall or stands on furniture.
    var footprint: GridBox? {
        let s = spot
        switch self {
        case .cactus, .gloves, .racket, .snowboard: return nil
        case .bench: return GridBox(x0: 3.9, y0: 0.3, x1: 5.2, y1: 3.4, z1: 1.9)
        case .bag: return GridBox(x0: s.x - 0.4, y0: s.y - 0.4, x1: s.x + 0.4, y1: s.y + 0.4, z1: 2.5)
        case .plant, .speaker: return GridBox(x0: s.x - 0.3, y0: s.y - 0.3, x1: s.x + 0.3, y1: s.y + 0.3, z1: 1)
        }
    }

    /// Back to front, as `HomePiece.depth`.
    var depth: Double {
        switch self {
        case .plant: 10.8
        case .bag: 9.0
        case .cactus: 3.7
        case .speaker: 11.1
        case .gloves, .racket, .snowboard: 0.6
        case .bench: 6.55
        }
    }
}

/// A place HAKU goes to, and the floor point he steps on or off it from.
enum HomeSpot: String, CaseIterable, Sendable {
    case idle, work, side, sofa, rest, box, shadowbox, bench, wardrobe, shop, window

    /// The middle of the rug, where HAKU waits.
    static let hub = GridPoint(x: 5.2, y: 6.6)

    /// Where HAKU's feet, seat or hips are.
    var point: GridPoint {
        switch self {
        case .idle, .shadowbox: Self.hub
        case .work, .side: GridPoint(x: 2.05, y: 1.85, z: 0.75)
        case .sofa: GridPoint(x: 1.9, y: 6.0, z: 0.6)
        case .rest: GridPoint(x: 8.0, y: 8.1, z: 0.65)
        case .box: GridPoint(x: 5.2, y: 4.1)
        // Lying on the pad, head in front of the rack, feet just past the near end.
        case .bench: GridPoint(x: 4.575, y: 3.55, z: 0.9)
        case .wardrobe: GridPoint(x: 7.85, y: 2.0)
        case .shop: GridPoint(x: 9.3, y: 2.0)
        case .window: GridPoint(x: 2.3, y: 0.75)
        }
    }

    /// The open floor next to a seat that HAKU walks to before getting on; the point itself elsewhere.
    var approach: GridPoint {
        switch self {
        case .work, .side: GridPoint(x: 3.1, y: 1.9)
        case .sofa: GridPoint(x: 2.6, y: 6.9)
        case .rest: GridPoint(x: 6.1, y: 7.6)
        case .bench: GridPoint(x: 4.6, y: 4.1)
        default: point
        }
    }

    /// How HAKU holds himself once there.
    var pose: HakuPose {
        switch self {
        case .idle: .stand
        case .work, .side: .back
        case .sofa: .sit
        case .rest: .lie
        case .box, .shadowbox: .box
        case .bench: .press
        case .wardrobe, .shop, .window: .backStand
        }
    }

    /// The depth while there; `nil` uses the walking depth of the spot.
    var depth: Double? {
        switch self {
        case .work, .side: 4.2
        case .sofa: 7.6
        case .rest: 14.0
        case .bench: HomeItem.bench.depth + 0.05
        default: nil
        }
    }

    /// Whether HAKU faces right (towards larger plan x) once there, or `nil` to keep the last facing.
    var facesRight: Bool? {
        switch self {
        case .box, .bench: true
        case .work, .side: false
        default: nil
        }
    }

    /// The walk from `start` to this spot: off the seat HAKU was on, the shortest way across the floor, then on.
    func path(from start: GridPoint, leaving previous: HomeSpot?, nav: HomeNav) -> [GridPoint] {
        var points = [start]
        var from = start
        if let previous, previous != self, start.distance(to: previous.point) < 0.05 {
            from = previous.approach
            points.append(from)
        }
        points += nav.path(from: from, to: approach).dropFirst()
        if approach != point { points.append(point) }
        // Drop stops that repeat the one before.
        return points.enumerated().compactMap { i, p in
            i > 0 && points[i - 1].distance(to: p) < 0.01 ? nil : p
        }
    }
}

/// How HAKU's body is posed.
enum HakuPose: Sendable, Equatable {
    case stand, walk, sit, lie, back, backStand, box, press, dangle, happy, stretch, tired
}

/// A walk along stops on the floor.
struct HomeWalk: Equatable, Sendable {
    let stops: [GridPoint]

    /// The walk's length in cells.
    var length: Double {
        zip(stops, stops.dropFirst()).reduce(0) { $0 + $1.0.distance(to: $1.1) }
    }

    /// Where HAKU is after walking `distance` cells, and the stop he walks towards.
    func position(after distance: Double) -> (point: GridPoint, heading: GridPoint) {
        guard let first = stops.first else { return (GridPoint(x: 0, y: 0), GridPoint(x: 0, y: 0)) }
        var left = max(0, distance)
        for (a, b) in zip(stops, stops.dropFirst()) {
            let d = a.distance(to: b)
            if left <= d, d > 0 {
                let f = left / d
                let p = GridPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f, z: a.z + (b.z - a.z) * f)
                return (p, b)
            }
            left -= d
        }
        let last = stops.last ?? first
        return (last, last)
    }
}
