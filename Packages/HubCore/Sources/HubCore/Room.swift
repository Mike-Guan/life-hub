import Foundation

// Issue #489. The home page's room: a read-only furniture catalog shipped with the app, and one layout per
// character saved in the App Group. The drawing lives in CompanionKit/Home; this file only holds the data.

/// A floor cell in the room grid.
public struct RoomCell: Hashable, Codable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

/// A point in grid units, relative to a piece's origin. `z` is the height.
public struct RoomPoint: Equatable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double = 0) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// Decodes the point; a missing value is 0.
    /// - Throws: `DecodingError` when the data is not an object.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        x = (try? values.decodeIfPresent(Double.self, forKey: .x)) ?? 0
        y = (try? values.decodeIfPresent(Double.self, forKey: .y)) ?? 0
        z = (try? values.decodeIfPresent(Double.self, forKey: .z)) ?? 0
    }
}

/// Something the character can do with a piece: sit, lie, use, look or box.
public struct RoomInteraction: Equatable, Codable, Sendable {
    public var id: String
    /// `sit`, `lie`, `use`, `look` or `box`. Kept as text, so a kind from a newer catalog still loads.
    public var kind: String
    /// Where the character is placed, relative to the piece's origin.
    public var anchor: RoomPoint
    /// `ne`, `se`, `sw` or `nw`.
    public var facing: String
    /// The cell next to the piece, relative to its origin, the character walks to first.
    public var approach: RoomPoint
    /// The action's name; each character maps it to her own animation.
    public var animation: String
    public var capacity: Int

    private enum CodingKeys: String, CodingKey {
        case id, kind, anchor, facing, approach, animation, capacity
    }

    /// Decodes the interaction; missing fields fall back to defaults.
    /// - Throws: `DecodingError` when `id` is missing.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        kind = (try? values.decodeIfPresent(String.self, forKey: .kind)) ?? "look"
        anchor = (try? values.decodeIfPresent(RoomPoint.self, forKey: .anchor)) ?? RoomPoint(x: 0, y: 0)
        facing = (try? values.decodeIfPresent(String.self, forKey: .facing)) ?? "se"
        approach = (try? values.decodeIfPresent(RoomPoint.self, forKey: .approach)) ?? anchor
        animation = (try? values.decodeIfPresent(String.self, forKey: .animation)) ?? kind
        capacity = (try? values.decodeIfPresent(Int.self, forKey: .capacity)) ?? 1
    }
}

/// A place on a piece where a small item can stand, such as a desk top.
public struct RoomSlot: Equatable, Codable, Sendable {
    public var id: String
    public var layer: String
    public var anchor: RoomPoint
}

/// One kind of furniture or item in the catalog.
public struct RoomPiece: Equatable, Codable, Sendable {
    /// Cells covered before rotation: `w` along x, `d` along y.
    public struct Footprint: Equatable, Codable, Sendable {
        public var w: Int
        public var d: Int
    }

    public var id: String
    /// `floor`, `wall`, `tabletop` or `rug`.
    public var layer: String
    public var footprint: Footprint
    public var height: Double
    /// Whether the character can't walk through the cells it covers.
    public var blocksWalk: Bool
    /// The allowed rotations in degrees.
    public var rotations: [Int]
    public var interactions: [RoomInteraction]
    public var slots: [RoomSlot]
    /// The colors the user can pick for the piece; empty when it can't be recolored.
    public var colors: [String]
    /// Where the piece stands when it comes out of storage with no spot of its own.
    public var defaultSpot: RoomCell?

    private enum CodingKeys: String, CodingKey {
        case id, layer, footprint, height, blocksWalk, rotations, interactions, slots, colors, defaultSpot
    }

    /// Decodes the piece; missing fields fall back to a 1×1 floor piece that blocks nothing.
    /// - Throws: `DecodingError` when `id` is missing.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        layer = (try? values.decodeIfPresent(String.self, forKey: .layer)) ?? "floor"
        footprint = (try? values.decodeIfPresent(Footprint.self, forKey: .footprint)) ?? Footprint(w: 1, d: 1)
        height = (try? values.decodeIfPresent(Double.self, forKey: .height)) ?? 0
        blocksWalk = (try? values.decodeIfPresent(Bool.self, forKey: .blocksWalk)) ?? false
        rotations = (try? values.decodeIfPresent([Int].self, forKey: .rotations)) ?? [0]
        // A broken entry drops only itself, not the whole piece.
        interactions = ((try? values.decodeIfPresent([Lossy<RoomInteraction>].self, forKey: .interactions)) ?? [])
            .compactMap(\.value)
        slots = ((try? values.decodeIfPresent([Lossy<RoomSlot>].self, forKey: .slots)) ?? []).compactMap(\.value)
        colors = (try? values.decodeIfPresent([String].self, forKey: .colors)) ?? []
        defaultSpot = try? values.decodeIfPresent(RoomCell.self, forKey: .defaultSpot)
    }
}

/// The furniture the app ships with. Read-only.
public struct RoomCatalog: Equatable, Codable, Sendable {
    public struct Grid: Equatable, Codable, Sendable {
        /// Cells along each side of the square floor.
        public var size: Int
        public var cell: Double
    }

    public var schemaVersion: Int
    public var grid: Grid
    public var pieces: [RoomPiece]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, grid, pieces
    }

    /// Decodes the catalog; pieces that can't be read are left out.
    /// - Throws: `DecodingError` when the data is not an object.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = (try? values.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? 1
        grid = (try? values.decodeIfPresent(Grid.self, forKey: .grid)) ?? Grid(size: 10, cell: 1)
        pieces = ((try? values.decodeIfPresent([Lossy<RoomPiece>].self, forKey: .pieces)) ?? []).compactMap(\.value)
    }

    /// The piece with `id`, `nil` when the catalog has none.
    public func piece(_ id: String) -> RoomPiece? {
        pieces.first { $0.id == id }
    }
}

/// One piece in a character's room: on the floor, on a wall, on another piece, or in storage.
public struct RoomPlacement: Equatable, Codable, Sendable, Identifiable {
    /// Another placement's slot this one stands on.
    public struct Mount: Equatable, Codable, Sendable {
        public var placement: UUID
        public var slot: String
    }

    public var id: UUID
    /// The catalog piece's id.
    public var piece: String
    /// The floor cell of the piece's origin; `nil` with no wall and no mount means in storage.
    public var x: Int?
    public var y: Int?
    public var rotation: Int
    public var color: String?
    /// `left` or `right` for wall items.
    public var wall: String?
    /// Along the wall, in cells.
    public var u: Double?
    /// Height on the wall, in cells.
    public var v: Double?
    public var on: Mount?
    // DW-02: fields a newer build added, written back unchanged.
    var other: [String: JSONValue] = [:]

    public init(
        id: UUID = UUID(), piece: String, at cell: RoomCell? = nil, rotation: Int = 0, color: String? = nil
    ) {
        self.id = id
        self.piece = piece
        self.x = cell?.x
        self.y = cell?.y
        self.rotation = rotation
        self.color = color
    }

    /// The floor cell of the piece's origin, `nil` for wall, mounted and stored items.
    public var cell: RoomCell? {
        guard let x, let y else { return nil }
        return RoomCell(x: x, y: y)
    }

    /// Whether the piece is in storage, not in the room.
    public var isStored: Bool {
        cell == nil && wall == nil && on == nil
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id, piece, x, y, rotation, color, wall, u, v, on
    }

    /// Decodes the placement; fields this build doesn't know are kept.
    /// - Throws: `DecodingError` when `id` or `piece` is missing.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        piece = try values.decode(String.self, forKey: .piece)
        x = try? values.decodeIfPresent(Int.self, forKey: .x)
        y = try? values.decodeIfPresent(Int.self, forKey: .y)
        rotation = (try? values.decodeIfPresent(Int.self, forKey: .rotation)) ?? 0
        color = try? values.decodeIfPresent(String.self, forKey: .color)
        wall = try? values.decodeIfPresent(String.self, forKey: .wall)
        u = try? values.decodeIfPresent(Double.self, forKey: .u)
        v = try? values.decodeIfPresent(Double.self, forKey: .v)
        on = try? values.decodeIfPresent(Mount.self, forKey: .on)
        other = try RoomKey.others(in: decoder, known: CodingKeys.allCases.map(\.rawValue))
    }

    /// Encodes the placement with the fields this build doesn't know.
    /// - Throws: `EncodingError` when a value can't be encoded.
    public func encode(to encoder: Encoder) throws {
        try RoomKey.write(other, to: encoder)
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(piece, forKey: .piece)
        try values.encodeIfPresent(x, forKey: .x)
        try values.encodeIfPresent(y, forKey: .y)
        try values.encode(rotation, forKey: .rotation)
        try values.encodeIfPresent(color, forKey: .color)
        try values.encodeIfPresent(wall, forKey: .wall)
        try values.encodeIfPresent(u, forKey: .u)
        try values.encodeIfPresent(v, forKey: .v)
        try values.encodeIfPresent(on, forKey: .on)
    }

    /// The floor cells the piece covers, given its catalog entry; empty when it isn't on the floor.
    public func cells(of piece: RoomPiece) -> [RoomCell] {
        guard let cell, piece.layer == "floor" || piece.layer == "rug" else { return [] }
        let turned = rotation % 180 != 0
        let w = turned ? piece.footprint.d : piece.footprint.w
        let d = turned ? piece.footprint.w : piece.footprint.d
        return (0..<w).flatMap { dx in (0..<d).map { dy in RoomCell(x: cell.x + dx, y: cell.y + dy) } }
    }
}

/// One character's room. A setting, so it is replaced in place.
public struct RoomLayout: Equatable, Codable, Sendable, Identifiable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var id: UUID
    /// The character's raw `Persona` name.
    public var persona: String
    public var createdAt: Date
    public var updatedAt: Date
    public var updatedBy: String
    public var deletedAt: Date?
    public var wallpaper: String?
    public var floor: String?
    public var placements: [RoomPlacement]
    // DW-02: placements this build can't read and fields a newer build added, written back unchanged.
    var unreadable: [JSONValue] = []
    var other: [String: JSONValue] = [:]

    public init(persona: Persona, now: Date = Date(), deviceID: String) {
        schemaVersion = Self.currentSchemaVersion
        id = UUID()
        self.persona = persona.rawValue
        createdAt = now
        updatedAt = now
        updatedBy = deviceID
        placements = []
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion, id, persona, createdAt, updatedAt, updatedBy, deletedAt, wallpaper, floor, placements
    }

    /// Decodes the layout; missing fields fall back to defaults and unknown ones are kept.
    /// - Throws: `DecodingError` when the data is not an object.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = (try? values.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? 1
        id = (try? values.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        persona = (try? values.decodeIfPresent(String.self, forKey: .persona)) ?? Persona.haku.rawValue
        let created = try? values.decodeIfPresent(Date.self, forKey: .createdAt)
        createdAt = created ?? .distantPast
        updatedAt = (try? values.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? createdAt
        updatedBy = (try? values.decodeIfPresent(String.self, forKey: .updatedBy)) ?? ""
        deletedAt = try? values.decodeIfPresent(Date.self, forKey: .deletedAt)
        wallpaper = try? values.decodeIfPresent(String.self, forKey: .wallpaper)
        floor = try? values.decodeIfPresent(String.self, forKey: .floor)
        let entries = (try? values.decodeIfPresent([PlacementEntry].self, forKey: .placements)) ?? []
        placements = entries.compactMap(\.placement)
        unreadable = entries.compactMap(\.raw)
        other = try RoomKey.others(in: decoder, known: CodingKeys.allCases.map(\.rawValue))
    }

    /// Encodes the layout, with what this build couldn't read after the rest.
    /// - Throws: `EncodingError` when a value can't be encoded.
    public func encode(to encoder: Encoder) throws {
        try RoomKey.write(other, to: encoder)
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(id, forKey: .id)
        try values.encode(persona, forKey: .persona)
        try values.encode(createdAt, forKey: .createdAt)
        try values.encode(updatedAt, forKey: .updatedAt)
        try values.encode(updatedBy, forKey: .updatedBy)
        try values.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try values.encodeIfPresent(wallpaper, forKey: .wallpaper)
        try values.encodeIfPresent(floor, forKey: .floor)
        try values.encode(placements.map(PlacementEntry.read) + unreadable.map(PlacementEntry.raw), forKey: .placements)
    }

    /// Records a change made on `deviceID` at `now`.
    public mutating func touch(now: Date = Date(), deviceID: String) {
        updatedAt = now
        updatedBy = deviceID
    }

    // 商店与家 同步方案 v0 §4 (Mike 2026-10-16): a room item bought anywhere goes to its own spot in the room.
    /// Places each of `items` not yet in the room at its catalog spot, or in storage when it has none.
    /// - Returns: `true` when something was added.
    @discardableResult
    public mutating func place(
        _ items: some Sequence<String>, catalog: RoomCatalog, now: Date = Date(), deviceID: String
    ) -> Bool {
        var placed = Set(placements.map(\.piece))
        var added = false
        for item in items where !placed.contains(item) {
            let id = UUID.derived(from: "room.\(persona).\(item)")
            placements.append(RoomPlacement(id: id, piece: item, at: catalog.piece(item)?.defaultSpot))
            placed.insert(item)
            added = true
        }
        if added { touch(now: now, deviceID: deviceID) }
        return added
    }

    static func defaultsKey(for persona: Persona) -> String { "roomLayout.\(persona.rawValue)" }
    static func migratedKey(for persona: Persona) -> String { "roomLayout.\(persona.rawValue).wardrobeMoved" }

    /// `persona`'s layout saved in `defaults`, or `nil` when none is saved or it can't be read.
    public static func stored(in defaults: UserDefaults, persona: Persona) -> RoomLayout? {
        let key = defaultsKey(for: persona)
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try HubJSON.decoder().decode(RoomLayout.self, from: data)
        } catch {
            // DW-02: the next save replaces what this build can't read, so a copy stays aside.
            defaults.set(data, forKey: "\(key).unreadable")
            return nil
        }
    }

    /// Saves the layout in `defaults` under its character.
    public func store(in defaults: UserDefaults) {
        guard let persona = Persona(rawValue: persona) else { return }
        defaults.set(try? HubJSON.encoder().encode(self), forKey: Self.defaultsKey(for: persona))
    }

    // Before the room page, a character showed one room item from the wardrobe's room slot. That item moves into
    // the layout once, at its catalog spot or into storage, and the wardrobe is left as it was.
    /// `persona`'s layout, made on first use, with the wardrobe's room item moved in once.
    public static func loaded(
        in defaults: UserDefaults, persona: Persona, catalog: RoomCatalog, now: Date = Date(), deviceID: String
    ) -> RoomLayout {
        var layout =
            stored(in: defaults, persona: persona) ?? RoomLayout(persona: persona, now: now, deviceID: deviceID)
        let migrated = migratedKey(for: persona)
        guard !defaults.bool(forKey: migrated) else { return layout }
        if let item = Wardrobe.stored(in: defaults, persona: persona).equipped[.room] {
            layout.place([item], catalog: catalog, now: now, deviceID: deviceID)
        }
        layout.store(in: defaults)
        defaults.set(true, forKey: migrated)
        return layout
    }
}

// Reads and writes the keys of an object that a type doesn't name, so they survive a save.
private struct RoomKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }

    static func others(in decoder: Decoder, known: [String]) throws -> [String: JSONValue] {
        let values = try decoder.container(keyedBy: RoomKey.self)
        var other: [String: JSONValue] = [:]
        for key in values.allKeys where !known.contains(key.stringValue) {
            other[key.stringValue] = try values.decode(JSONValue.self, forKey: key)
        }
        return other
    }

    static func write(_ other: [String: JSONValue], to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: RoomKey.self)
        for (key, value) in other {
            try values.encode(value, forKey: RoomKey(stringValue: key))
        }
    }
}

// An array entry that is `nil` when it can't be read, so one bad entry doesn't fail the array.
private struct Lossy<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

// A placement this build reads, or one it can't, kept as it was.
private enum PlacementEntry: Codable {
    case read(RoomPlacement)
    case raw(JSONValue)

    init(from decoder: Decoder) throws {
        if let placement = try? RoomPlacement(from: decoder) {
            self = .read(placement)
        } else {
            self = .raw(try JSONValue(from: decoder))
        }
    }

    var placement: RoomPlacement? {
        if case .read(let placement) = self { return placement }
        return nil
    }

    var raw: JSONValue? {
        if case .raw(let value) = self { return value }
        return nil
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .read(let placement): try placement.encode(to: encoder)
        case .raw(let value): try value.encode(to: encoder)
        }
    }
}
