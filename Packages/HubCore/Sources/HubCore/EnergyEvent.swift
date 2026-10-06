import Foundation

/// Mike's energy in three steps, as the lock-screen buttons show it.
public enum EnergyLevel: String, Codable, CaseIterable, Sendable {
    case low
    case okay
    case full

    /// Label on buttons and widgets.
    public var title: String {
        switch self {
        case .low: "低电量"
        case .okay: "还行"
        case .full: "满格"
        }
    }

    /// The 0-100 value the companion's `energy` input takes for this level.
    public var value: Double {
        switch self {
        case .low: 20
        case .okay: 55
        case .full: 85
        }
    }
}

/// One fact that moves energy. Stored append-only; energy is computed from these, never stored.
public struct EnergyEvent: Codable, Identifiable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    /// What happened.
    public enum Kind: String, Codable, Sendable {
        /// Last night's sleep. `at` is when it ended; `sleepMinutes` is the time asleep.
        case sleep
        /// Mike tapped low / okay / full. `level` is what he picked.
        case selfReport
    }

    public var schemaVersion: Int
    public var id: UUID
    public var kind: Kind
    public var at: Date
    public var sleepMinutes: Int?
    public var level: EnergyLevel?
    public var createdAt: Date
    public var updatedAt: Date
    public var updatedBy: String
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        kind: Kind,
        at: Date = .now,
        sleepMinutes: Int? = nil,
        level: EnergyLevel? = nil,
        deviceID: String
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.kind = kind
        self.at = at
        self.sleepMinutes = sleepMinutes
        self.level = level
        self.createdAt = at
        self.updatedAt = at
        self.updatedBy = deviceID
        self.deletedAt = nil
    }

    /// A night's sleep that ended at `endedAt`.
    public static func sleep(minutes: Int, endedAt: Date, deviceID: String) -> EnergyEvent {
        EnergyEvent(kind: .sleep, at: endedAt, sleepMinutes: minutes, deviceID: deviceID)
    }

    /// Mike's own rating at `at`.
    public static func selfReport(_ level: EnergyLevel, at: Date = .now, deviceID: String) -> EnergyEvent {
        EnergyEvent(kind: .selfReport, at: at, level: level, deviceID: deviceID)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, kind, at, sleepMinutes, level, createdAt, updatedAt, updatedBy, deletedAt
    }

    // Defaults let records written by an older or newer build still load. An unknown kind or level
    // throws, so the log keeps the raw record instead of guessing.
    /// Decodes an event. Only `id`, `kind` and `at` are required.
    /// - Throws: `DecodingError` when a required field is missing or invalid.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        id = try values.decode(UUID.self, forKey: .id)
        kind = try values.decode(Kind.self, forKey: .kind)
        at = try values.decode(Date.self, forKey: .at)
        sleepMinutes = try values.decodeIfPresent(Int.self, forKey: .sleepMinutes)
        level = try values.decodeIfPresent(EnergyLevel.self, forKey: .level)
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt) ?? at
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        updatedBy = try values.decodeIfPresent(String.self, forKey: .updatedBy) ?? "unknown"
        deletedAt = try values.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

/// The append-only history of energy events. This is the on-disk document.
public struct EnergyLog: RecordLog, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var events: [EnergyEvent]
    // Kept as-is and written back on save, so an older build never deletes newer data (DW-02).
    /// Records this build can't read.
    public var unreadable: [JSONValue]

    public var records: [EnergyEvent] {
        get { events }
        set { events = newValue }
    }

    public init() { self.init(events: []) }

    public init(events: [EnergyEvent]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.events = events
        self.unreadable = []
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, events }

    /// Decodes the log, moving records that fail to decode into `unreadable`.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        let items = try values.decodeIfPresent([LossyRecord<EnergyEvent>].self, forKey: .events) ?? []
        events = items.compactMap(\.value)
        unreadable = items.filter { $0.value == nil }.map(\.raw)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        var list = values.nestedUnkeyedContainer(forKey: .events)
        for event in events { try list.encode(event) }
        for raw in unreadable { try list.encode(raw) }
    }

    /// Non-deleted events, oldest first.
    public var active: [EnergyEvent] {
        events.filter { $0.deletedAt == nil }.sorted { $0.at < $1.at }
    }
}

extension EnergyLog {
    // EnergyStore is the log's single writer, so this only reads the file and never moves it aside.
    /// The log in the file at `url`, or an empty one when there is none or it can't be read.
    public static func read(from url: URL?) -> EnergyLog {
        guard let url, let data = try? Data(contentsOf: url) else { return EnergyLog() }
        return (try? HubJSON.decoder().decode(EnergyLog.self, from: data)) ?? EnergyLog()
    }
}
