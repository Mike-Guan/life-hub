import Foundation

// Issue #485: walking on a grid of half cells. The shipping home moves this to HubCore with the layout data.

/// Where HAKU can walk in the room, and the shortest way between two floor points.
struct HomeNav: Sendable {
    /// Cells per grid unit.
    static let resolution = 2
    /// How far HAKU's feet keep from furniture and walls, in grid units.
    static let clearance = 0.3

    private let side: Int
    private let open: [Bool]

    /// Builds the walkable floor around `blocks`.
    init(blocks: [GridBox], size: Double = HomeGrid.size) {
        side = Int(size) * Self.resolution
        var open = [Bool](repeating: true, count: side * side)
        for j in 0..<side {
            for i in 0..<side {
                let p = Self.center(i, j)
                let c = Self.clearance
                let nearWall = p.x < c + 0.1 || p.y < c + 0.1 || p.x > size - c || p.y > size - c
                let hit = blocks.contains { b in
                    p.x > b.x0 - c && p.x < b.x1 + c && p.y > b.y0 - c && p.y < b.y1 + c
                }
                open[j * side + i] = !nearWall && !hit
            }
        }
        self.open = open
    }

    /// The room as the prototype lays it out, with the items standing in it.
    static func room(items: Set<HomeItem> = []) -> HomeNav {
        let solid = HomePiece.allCases.filter(\.blocksWalking).flatMap(\.boxes)
        let standing = items.compactMap(\.footprint)
        return HomeNav(blocks: solid + standing)
    }

    /// Whether HAKU can stand at `p`.
    func isOpen(_ p: GridPoint) -> Bool {
        guard let (i, j) = cell(p) else { return false }
        return open[j * side + i]
    }

    /// The open point nearest to `p`.
    func nearestOpen(to p: GridPoint) -> GridPoint {
        if isOpen(p) { return GridPoint(x: p.x, y: p.y) }
        var best: GridPoint?
        var bestDistance = Double.infinity
        for j in 0..<side {
            for i in 0..<side where open[j * side + i] {
                let c = Self.center(i, j)
                let d = c.distance(to: p)
                if d < bestDistance {
                    best = c
                    bestDistance = d
                }
            }
        }
        return best ?? p
    }

    /// The shortest walk from `start` to `goal`, smoothed to straight legs, or a straight line when either end
    /// is blocked and nothing better exists.
    func path(from start: GridPoint, to goal: GridPoint) -> [GridPoint] {
        let a = nearestOpen(to: start)
        let b = nearestOpen(to: goal)
        guard let from = cell(a), let to = cell(b) else { return [start, goal] }
        let cells = search(from: from, to: to)
        var points = [start]
        if a.distance(to: start) > 0.01 { points.append(a) }
        points += cells.dropFirst().dropLast().map { Self.center($0.0, $0.1) }
        if b.distance(to: goal) > 0.01 { points.append(b) }
        points.append(goal)
        return smooth(points)
    }

    // MARK: Search

    private func search(from: (Int, Int), to: (Int, Int)) -> [(Int, Int)] {
        let count = side * side
        let goal = to.1 * side + to.0
        var cost = [Double](repeating: .infinity, count: count)
        var came = [Int](repeating: -1, count: count)
        var closed = [Bool](repeating: false, count: count)
        let startIndex = from.1 * side + from.0
        cost[startIndex] = 0
        var frontier: Set<Int> = [startIndex]
        func guess(_ k: Int) -> Double {
            hypot(Double(k % side - to.0), Double(k / side - to.1))
        }
        while let k = frontier.min(by: { cost[$0] + guess($0) < cost[$1] + guess($1) }) {
            if k == goal { break }
            frontier.remove(k)
            closed[k] = true
            let (i, j) = (k % side, k / side)
            for (di, dj) in [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)] {
                let (ni, nj) = (i + di, j + dj)
                guard ni >= 0, nj >= 0, ni < side, nj < side else { continue }
                let n = nj * side + ni
                guard open[n], !closed[n] else { continue }
                // A diagonal step needs both cells beside it open, so HAKU never cuts a corner.
                if di != 0, dj != 0, !open[j * side + ni] || !open[nj * side + i] { continue }
                let step = cost[k] + ((di != 0 && dj != 0) ? 2.0.squareRoot() : 1)
                if step < cost[n] {
                    cost[n] = step
                    came[n] = k
                    frontier.insert(n)
                }
            }
        }
        guard came[goal] >= 0 || goal == startIndex else { return [from, to] }
        var cells = [(goal % side, goal / side)]
        var k = goal
        while came[k] >= 0 {
            k = came[k]
            cells.append((k % side, k / side))
        }
        return cells.reversed()
    }

    // Drops stops that a straight, open leg can skip.
    private func smooth(_ points: [GridPoint]) -> [GridPoint] {
        guard points.count > 2 else { return points }
        var result = [points[0]]
        var i = 0
        while i < points.count - 1 {
            var j = points.count - 1
            while j > i + 1, !clear(points[i], points[j]) { j -= 1 }
            result.append(points[j])
            i = j
        }
        return result
    }

    private func clear(_ a: GridPoint, _ b: GridPoint) -> Bool {
        let steps = max(2, Int(a.distance(to: b) * 8))
        return (1..<steps).allSatisfy { k in
            let f = Double(k) / Double(steps)
            return isOpen(GridPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f))
        }
    }

    private func cell(_ p: GridPoint) -> (Int, Int)? {
        let i = Int((p.x * Double(Self.resolution)).rounded(.down))
        let j = Int((p.y * Double(Self.resolution)).rounded(.down))
        guard i >= 0, j >= 0, i < side, j < side else { return nil }
        return (i, j)
    }

    private static func center(_ i: Int, _ j: Int) -> GridPoint {
        GridPoint(x: (Double(i) + 0.5) / Double(resolution), y: (Double(j) + 0.5) / Double(resolution))
    }
}
