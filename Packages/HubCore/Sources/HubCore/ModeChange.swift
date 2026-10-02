import Foundation

/// One switch into a mode. Stored append-only; the current mode is the latest non-deleted change.
public struct ModeChange: Codable, Identifiable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    /// Where the switch came from, strongest evidence first.
    public enum Source: String, Codable, Sendable {
        case manual
        case location
        case focus
        case calendar
        case schedule
        case suggestion
        case inferred

        public var isManual: Bool { self == .manual }
    }

    public var schemaVersion: Int
    public var id: UUID
    public var mode: Mode
    public var source: Source
    /// Optional sub-activity, e.g. groceries / shows / gym inside chill.
    public var tag: String?
    public var at: Date
    public var createdAt: Date
    public var updatedAt: Date
    public var updatedBy: String
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        mode: Mode,
        source: Source = .manual,
        tag: String? = nil,
        at: Date = .now,
        deviceID: String
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.mode = mode
        self.source = source
        self.tag = tag
        self.at = at
        self.createdAt = at
        self.updatedAt = at
        self.updatedBy = deviceID
        self.deletedAt = nil
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, mode, source, tag, at, createdAt, updatedAt, updatedBy, deletedAt
    }

    /// Tolerant decoding: only `id`, `mode` and `at` are required, everything else has a default,
    /// so records written by an older or newer build still load.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        id = try values.decode(UUID.self, forKey: .id)
        mode = try values.decode(Mode.self, forKey: .mode)
        let rawSource = try values.decodeIfPresent(String.self, forKey: .source)
        // Unknown or missing sources count as the weakest evidence.
        source = rawSource.flatMap(Source.init(rawValue:)) ?? .inferred
        tag = try values.decodeIfPresent(String.self, forKey: .tag)
        at = try values.decode(Date.self, forKey: .at)
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt) ?? at
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        updatedBy = try values.decodeIfPresent(String.self, forKey: .updatedBy) ?? "unknown"
        deletedAt = try values.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}
