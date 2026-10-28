import Foundation

// Issue #489. Where the character can walk in her room, and the way from where she stands to a spot. The scene
// draws the walk; this only picks the cells.

/// The room's floor cells and the ones furniture blocks.
public struct RoomGrid: Equatable, Sendable {
    /// Cells along each side of the square floor.
    public let size: Int
    public private(set) var blocked: Set<RoomCell>

    public init(size: Int, blocked: Set<RoomCell> = []) {
        self.size = size
        self.blocked = blocked
    }

    /// The grid for `layout`: every floor cell but those under pieces that block walking.
    public init(layout: RoomLayout, catalog: RoomCatalog) {
        var blocked: Set<RoomCell> = []
        for placement in layout.placements {
            guard let piece = catalog.piece(placement.piece), piece.blocksWalk else { continue }
            blocked.formUnion(placement.cells(of: piece))
        }
        self.init(size: catalog.grid.size, blocked: blocked)
    }

    /// Whether `cell` is on the floor and free.
    public func isWalkable(_ cell: RoomCell) -> Bool {
        (0..<size).contains(cell.x) && (0..<size).contains(cell.y) && !blocked.contains(cell)
    }

    /// The free cell closest to `cell`, `cell` itself when it is free, `nil` when the floor is full.
    public func nearestWalkable(to cell: RoomCell) -> RoomCell? {
        func distance(_ other: RoomCell) -> Int {
            (other.x - cell.x) * (other.x - cell.x) + (other.y - cell.y) * (other.y - cell.y)
        }
        let free = (0..<size).flatMap { y in (0..<size).map { x in RoomCell(x: x, y: y) } }.filter(isWalkable)
        return free.min { distance($0) < distance($1) }
    }
}

/// Paths across the room grid.
public enum RoomPath {
    /// The shortest walk from `start` to `goal`, both included, `nil` when there is none.
    ///
    /// Steps go to the eight neighbours; a diagonal step only when both cells beside it are free, so the walk
    /// never cuts a furniture corner.
    public static func find(from start: RoomCell, to goal: RoomCell, in grid: RoomGrid) -> [RoomCell]? {
        guard grid.isWalkable(start), grid.isWalkable(goal) else { return nil }
        var open: Set<RoomCell> = [start]
        var cameFrom: [RoomCell: RoomCell] = [:]
        var cost: [RoomCell: Double] = [start: 0]
        // The grid is small (10 × 10), so a scan beats a heap. Ties go to the lower cell, so walks repeat.
        while let current = open.min(by: { lhs, rhs in
            let left = cost[lhs, default: .infinity] + distance(lhs, goal)
            let right = cost[rhs, default: .infinity] + distance(rhs, goal)
            return left != right ? left < right : (lhs.y, lhs.x) < (rhs.y, rhs.x)
        }) {
            if current == goal { return walk(back: goal, through: cameFrom) }
            open.remove(current)
            for next in neighbours(of: current, in: grid) {
                let through = cost[current, default: .infinity] + distance(current, next)
                if through < cost[next, default: .infinity] {
                    cost[next] = through
                    cameFrom[next] = current
                    open.insert(next)
                }
            }
        }
        return nil
    }

    /// `path` with the corners it doesn't need taken out: a cell stays only when the line past it would cross
    /// a blocked cell.
    public static func smoothed(_ path: [RoomCell], in grid: RoomGrid) -> [RoomCell] {
        guard path.count > 2 else { return path }
        var result = [path[0]]
        var anchor = 0
        while anchor < path.count - 1 {
            var next = anchor + 1
            while next + 1 < path.count, isClear(from: path[anchor], to: path[next + 1], in: grid) {
                next += 1
            }
            result.append(path[next])
            anchor = next
        }
        return result
    }

    // Octile distance: diagonal steps cost √2.
    static func distance(_ a: RoomCell, _ b: RoomCell) -> Double {
        let dx = Double(abs(a.x - b.x))
        let dy = Double(abs(a.y - b.y))
        return max(dx, dy) + (2.0.squareRoot() - 1) * min(dx, dy)
    }

    private static func neighbours(of cell: RoomCell, in grid: RoomGrid) -> [RoomCell] {
        var result: [RoomCell] = []
        for dx in -1...1 {
            for dy in -1...1 where dx != 0 || dy != 0 {
                let next = RoomCell(x: cell.x + dx, y: cell.y + dy)
                guard grid.isWalkable(next) else { continue }
                if dx != 0, dy != 0 {
                    let side = RoomCell(x: cell.x + dx, y: cell.y)
                    let other = RoomCell(x: cell.x, y: cell.y + dy)
                    guard grid.isWalkable(side), grid.isWalkable(other) else { continue }
                }
                result.append(next)
            }
        }
        return result
    }

    private static func walk(back goal: RoomCell, through cameFrom: [RoomCell: RoomCell]) -> [RoomCell] {
        var path = [goal]
        while let previous = cameFrom[path[path.count - 1]] {
            path.append(previous)
        }
        return path.reversed()
    }

    // The character is about half a cell wide, so the line is checked at a quarter cell to each side.
    static func isClear(from a: RoomCell, to b: RoomCell, in grid: RoomGrid) -> Bool {
        let steps = max(1, Int((distance(a, b) * 8).rounded(.up)))
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let x = Double(a.x) + Double(b.x - a.x) * t
            let y = Double(a.y) + Double(b.y - a.y) * t
            for (ox, oy) in [(-0.25, -0.25), (-0.25, 0.25), (0.25, -0.25), (0.25, 0.25)] {
                let cell = RoomCell(x: Int((x + ox).rounded()), y: Int((y + oy).rounded()))
                if !grid.isWalkable(cell) { return false }
            }
        }
        return true
    }
}
