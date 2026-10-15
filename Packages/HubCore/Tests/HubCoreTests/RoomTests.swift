import Foundation
import Testing

@testable import HubCore

@Suite struct RoomTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    let catalogJSON = """
        {
          "schemaVersion": 1,
          "grid": { "size": 10, "cell": 1.0 },
          "pieces": [
            {
              "id": "bed.basic", "layer": "floor", "footprint": { "w": 2, "d": 3 }, "height": 0.65,
              "blocksWalk": true, "rotations": [0, 90], "colors": ["green", "cream"],
              "interactions": [
                { "id": "lie", "kind": "lie", "anchor": { "x": 0.9, "y": 1.7, "z": 0.65 }, "facing": "se",
                  "approach": { "x": -0.6, "y": 1.5 }, "animation": "lie", "capacity": 1 },
                { "kind": "broken" }
              ],
              "slots": [ { "id": "top", "layer": "tabletop", "anchor": { "x": 0.5, "y": 0.5, "z": 0.65 } } ]
            },
            { "id": "room.plant", "defaultSpot": { "x": 1, "y": 8 } },
            { "layer": "floor" }
          ]
        }
        """

    func makeCatalog() throws -> RoomCatalog {
        try JSONDecoder().decode(RoomCatalog.self, from: Data(catalogJSON.utf8))
    }

    @Test func catalogReadsPiecesAndSkipsBrokenOnes() throws {
        let catalog = try makeCatalog()
        #expect(catalog.grid.size == 10)
        #expect(catalog.pieces.map(\.id) == ["bed.basic", "room.plant"])
        let bed = try #require(catalog.piece("bed.basic"))
        #expect(bed.blocksWalk)
        #expect(bed.interactions.map(\.id) == ["lie"])
        #expect(bed.interactions.first?.approach == RoomPoint(x: -0.6, y: 1.5))
        #expect(bed.slots.first?.id == "top")
        #expect(bed.colors == ["green", "cream"])
        let plant = try #require(catalog.piece("room.plant"))
        #expect(plant.footprint == RoomPiece.Footprint(w: 1, d: 1))
        #expect(plant.layer == "floor")
        #expect(!plant.blocksWalk)
        #expect(plant.colors.isEmpty)
        #expect(plant.defaultSpot == RoomCell(x: 1, y: 8))
        #expect(catalog.piece("sofa") == nil)
    }

    @Test func aTurnedPieceSwapsItsFootprint() throws {
        let bed = try #require(try makeCatalog().piece("bed.basic"))
        let flat = RoomPlacement(piece: "bed.basic", at: RoomCell(x: 7, y: 6))
        #expect(flat.cells(of: bed).count == 6)
        #expect(flat.cells(of: bed).contains(RoomCell(x: 8, y: 8)))
        let turned = RoomPlacement(piece: "bed.basic", at: RoomCell(x: 7, y: 6), rotation: 90)
        #expect(turned.cells(of: bed).contains(RoomCell(x: 9, y: 7)))
        #expect(!turned.cells(of: bed).contains(RoomCell(x: 8, y: 8)))
        #expect(RoomPlacement(piece: "bed.basic").cells(of: bed).isEmpty)
        #expect(RoomPlacement(piece: "bed.basic").isStored)
    }

    @Test func layoutKeepsWhatANewerBuildWrote() throws {
        let json = """
            {
              "schemaVersion": 2, "id": "7F1E3C2A-0000-4000-8000-000000000001", "persona": "haku",
              "createdAt": "2027-01-15T08:00:00Z", "updatedAt": "2027-01-15T08:00:00Z", "updatedBy": "phone",
              "wallpaper": "wall.cream", "lights": "warm",
              "placements": [
                { "id": "7F1E3C2A-0000-4000-8000-000000000002", "piece": "bed.basic", "x": 7, "y": 6,
                  "rotation": 0, "color": "green", "glow": true },
                { "id": "7F1E3C2A-0000-4000-8000-000000000003", "piece": "cactus",
                  "on": { "placement": "7F1E3C2A-0000-4000-8000-000000000002", "slot": "top" } },
                { "piece": "no id" }
              ]
            }
            """
        let layout = try HubJSON.decoder().decode(RoomLayout.self, from: Data(json.utf8))
        #expect(layout.placements.count == 2)
        #expect(layout.placements[0].cell == RoomCell(x: 7, y: 6))
        #expect(layout.placements[1].on?.slot == "top")
        #expect(!layout.placements[1].isStored)
        #expect(layout.deletedAt == nil)

        let again = try HubJSON.decoder().decode(RoomLayout.self, from: HubJSON.encoder().encode(layout))
        #expect(again == layout)
        let object = try JSONDecoder().decode(JSONValue.self, from: HubJSON.encoder().encode(layout))
        guard case .object(let fields) = object, case .array(let placements) = fields["placements"] else {
            Issue.record("not an object")
            return
        }
        #expect(fields["lights"] == .string("warm"))
        #expect(placements.count == 3)
        guard case .object(let bed) = placements[0] else { return }
        #expect(bed["glow"] == .bool(true))
    }

    @Test func layoutFillsMissingFields() throws {
        let layout = try HubJSON.decoder().decode(RoomLayout.self, from: Data("{}".utf8))
        #expect(layout.schemaVersion == 1)
        #expect(layout.persona == "haku")
        #expect(layout.placements.isEmpty)
        #expect(layout.updatedAt == layout.createdAt)
    }

    @Test func storesEachCharactersLayout() throws {
        let suite = "RoomTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(RoomLayout.stored(in: defaults, persona: .haku) == nil)
        var layout = RoomLayout(persona: .kuro, now: now, deviceID: "phone")
        layout.placements.append(RoomPlacement(piece: "room.plant", at: RoomCell(x: 2, y: 3)))
        layout.store(in: defaults)
        #expect(RoomLayout.stored(in: defaults, persona: .kuro) == layout)
        #expect(RoomLayout.stored(in: defaults, persona: .haku) == nil)

        defaults.set(Data("[1]".utf8), forKey: "roomLayout.haku")
        #expect(RoomLayout.stored(in: defaults, persona: .haku) == nil)
        #expect(defaults.data(forKey: "roomLayout.haku.unreadable") == Data("[1]".utf8))
    }

    @Test func theWardrobesRoomItemMovesInOnce() throws {
        let suite = "RoomTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let catalog = try makeCatalog()
        Wardrobe(equipped: [.room: "room.plant"]).store(in: defaults, persona: .haku)
        Wardrobe(equipped: [.room: "kuro.room.lamp"]).store(in: defaults, persona: .kuro)

        let haku = RoomLayout.loaded(in: defaults, persona: .haku, catalog: catalog, now: now, deviceID: "phone")
        #expect(haku.placements.map(\.piece) == ["room.plant"])
        #expect(haku.placements.first?.cell == RoomCell(x: 1, y: 8))
        #expect(RoomLayout.stored(in: defaults, persona: .haku) == haku)
        // The wardrobe is left as it was.
        #expect(Wardrobe.stored(in: defaults, persona: .haku).equipped[.room] == "room.plant")

        // A piece the catalog has no spot for goes into storage.
        let kuro = RoomLayout.loaded(in: defaults, persona: .kuro, catalog: catalog, now: now, deviceID: "phone")
        #expect(kuro.placements.first?.piece == "kuro.room.lamp")
        #expect(kuro.placements.first?.isStored == true)

        // Moving the plant into storage sticks: the wardrobe isn't read again.
        var moved = haku
        moved.placements[0].x = nil
        moved.placements[0].y = nil
        moved.store(in: defaults)
        Wardrobe(equipped: [.room: "room.bag"]).store(in: defaults, persona: .haku)
        let later = RoomLayout.loaded(in: defaults, persona: .haku, catalog: catalog, now: now, deviceID: "phone")
        #expect(later == moved)
    }

    @Test func anEmptyWardrobeMakesAnEmptyRoom() throws {
        let suite = "RoomTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let catalog = try makeCatalog()
        let layout = RoomLayout.loaded(in: defaults, persona: .haku, catalog: catalog, now: now, deviceID: "a")
        #expect(layout.placements.isEmpty)
        #expect(layout.updatedBy == "a")
        var touched = layout
        touched.touch(now: now.addingTimeInterval(60), deviceID: "b")
        #expect(touched.updatedBy == "b")
        #expect(touched.updatedAt > layout.updatedAt)
    }
}
