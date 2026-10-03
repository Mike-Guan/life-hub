import Foundation

// The app computes it; readers never touch the full log.
/// What widgets and the menu bar read.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var mode: Mode?
    public var since: Date?
    /// Today's energy, `nil` when unknown.
    public var energy: EnergyLevel?
    /// Bedtime state when the snapshot was taken, `nil` in snapshots from older builds.
    public var bedtime: Bedtime?
    public var updatedAt: Date

    public init(
        mode: Mode?,
        since: Date?,
        energy: EnergyLevel? = nil,
        bedtime: Bedtime? = nil,
        updatedAt: Date
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.mode = mode
        self.since = since
        self.energy = energy
        self.bedtime = bedtime
        self.updatedAt = updatedAt
    }

    public init(log: ModeLog, energy: EnergyLevel? = nil, bedtime: Bedtime? = nil, now: Date = .now) {
        self.init(mode: log.current?.mode, since: log.current?.at, energy: energy, bedtime: bedtime, updatedAt: now)
    }
}
