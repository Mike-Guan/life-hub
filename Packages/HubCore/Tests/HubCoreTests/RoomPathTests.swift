import Foundation
import Testing

@testable import HubCore

@Suite struct RoomPathTests {
    func cell(_ x: Int, _ y: Int) -> RoomCell { RoomCell(x: x, y: y) }

    // A wall of blocked cells at x = 4 from y = 0 to `to`.
    func wall(to end: Int) -> RoomGrid {
        RoomGrid(size: 10, blocked: Set((0...end).map { cell(4, $0) }))
    }

    @Test func anOpenFloorWalksStraight() throws {
        let grid = RoomGrid(size: 10)
        let path = try #require(RoomPath.find(from: cell(1, 1), to: cell(6, 1), in: grid))
        #expect(path == (1...6).map { cell($0, 1) })
        let diagonal = try #require(RoomPath.find(from: cell(0, 0), to: cell(3, 3), in: grid))
        #expect(diagonal == [cell(0, 0), cell(1, 1), cell(2, 2), cell(3, 3)])
        #expect(RoomPath.find(from: cell(2, 2), to: cell(2, 2), in: grid) == [cell(2, 2)])
    }

    @Test func theWalkGoesAroundFurniture() throws {
        let grid = wall(to: 7)
        let path = try #require(RoomPath.find(from: cell(2, 2), to: cell(6, 2), in: grid))
        #expect(path.first == cell(2, 2))
        #expect(path.last == cell(6, 2))
        #expect(path.allSatisfy(grid.isWalkable))
        #expect(path.contains { $0.y >= 8 })
        // Each step is to a neighbour.
        for (a, b) in zip(path, path.dropFirst()) {
            #expect(max(abs(a.x - b.x), abs(a.y - b.y)) == 1)
        }
    }

    @Test func aDiagonalNeverCutsACorner() throws {
        let grid = RoomGrid(size: 3, blocked: [cell(1, 0)])
        let path = try #require(RoomPath.find(from: cell(0, 0), to: cell(1, 1), in: grid))
        #expect(path == [cell(0, 0), cell(0, 1), cell(1, 1)])
    }

    @Test func noWalkWhenBlockedOrOffTheFloor() {
        let grid = wall(to: 9)
        #expect(RoomPath.find(from: cell(2, 2), to: cell(6, 2), in: grid) == nil)
        #expect(RoomPath.find(from: cell(4, 2), to: cell(2, 2), in: grid) == nil)
        #expect(RoomPath.find(from: cell(2, 2), to: cell(10, 2), in: grid) == nil)
    }

    @Test func smoothingDropsCornersItDoesNotNeed() throws {
        let open = RoomGrid(size: 10)
        let stairs = [cell(0, 0), cell(1, 0), cell(1, 1), cell(2, 1), cell(2, 2)]
        #expect(RoomPath.smoothed(stairs, in: open) == [cell(0, 0), cell(2, 2)])
        #expect(RoomPath.smoothed([cell(0, 0), cell(1, 0)], in: open) == [cell(0, 0), cell(1, 0)])

        let grid = wall(to: 7)
        let path = try #require(RoomPath.find(from: cell(2, 2), to: cell(6, 2), in: grid))
        let smooth = RoomPath.smoothed(path, in: grid)
        #expect(smooth.count < path.count)
        #expect(smooth.first == cell(2, 2))
        #expect(smooth.last == cell(6, 2))
        for (a, b) in zip(smooth, smooth.dropFirst()) {
            #expect(RoomPath.isClear(from: a, to: b, in: grid))
        }
        #expect(!RoomPath.isClear(from: cell(2, 2), to: cell(6, 2), in: grid))
    }

    @Test func theNearestFreeCell() {
        let grid = wall(to: 9)
        #expect(grid.nearestWalkable(to: cell(2, 2)) == cell(2, 2))
        #expect(grid.nearestWalkable(to: cell(4, 5)) == cell(3, 5))
        #expect(RoomGrid(size: 1, blocked: [cell(0, 0)]).nearestWalkable(to: cell(0, 0)) == nil)
    }

    @Test func furnitureThatBlocksMakesTheGrid() throws {
        let json = """
            {
              "grid": { "size": 6, "cell": 1.0 },
              "pieces": [
                { "id": "bed", "footprint": { "w": 2, "d": 3 }, "blocksWalk": true },
                { "id": "rug", "layer": "rug", "footprint": { "w": 2, "d": 2 } }
              ]
            }
            """
        let catalog = try JSONDecoder().decode(RoomCatalog.self, from: Data(json.utf8))
        var layout = RoomLayout(persona: .haku, deviceID: "phone")
        layout.placements = [
            RoomPlacement(piece: "bed", at: cell(0, 0), rotation: 90),
            RoomPlacement(piece: "rug", at: cell(3, 3)),
            RoomPlacement(piece: "bed"),
        ]
        let grid = RoomGrid(layout: layout, catalog: catalog)
        #expect(grid.size == 6)
        #expect(grid.blocked == [cell(0, 0), cell(1, 0), cell(2, 0), cell(0, 1), cell(1, 1), cell(2, 1)])
        #expect(grid.isWalkable(cell(3, 3)))
    }
}
