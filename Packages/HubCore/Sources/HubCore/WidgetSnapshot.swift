import Foundation

// The app computes it; readers never touch the full log.
/// What widgets and the menu bar read.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var mode: Mode?
    public var since: Date?
    public var updatedAt: Date

    public init(mode: Mode?, since: Date?, updatedAt: Date) {
        self.schemaVersion = Self.currentSchemaVersion
        self.mode = mode
        self.since = since
        self.updatedAt = updatedAt
    }

    public init(log: ModeLog, now: Date = .now) {
        self.init(mode: log.current?.mode, since: log.current?.at, updatedAt: now)
    }
}
