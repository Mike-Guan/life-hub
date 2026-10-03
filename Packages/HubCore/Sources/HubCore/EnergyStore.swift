import Foundation
import Observation

/// Owns the energy event log on this device. Single writer for `EnergyLog`.
@MainActor
@Observable
public final class EnergyStore {
    public private(set) var log: EnergyLog
    /// Last load or save failure, for the UI to show.
    public private(set) var lastError: String?
    public let deviceID: String

    @ObservationIgnored private var file: LogFile<EnergyLog>

    /// - Parameter fileURL: where the log lives; `nil` keeps everything in memory (previews, tests).
    public init(fileURL: URL?, deviceID: String) {
        var file = LogFile<EnergyLog>(url: fileURL, name: "energy 记录")
        var log = EnergyLog()
        let error = file.load(into: &log)
        self.file = file
        self.deviceID = deviceID
        self.log = log
        self.lastError = error
    }

    /// Adds `event` unless an event with the same id is already stored.
    /// - Returns: `false` when the event was already there.
    @discardableResult
    public func record(_ event: EnergyEvent) -> Bool {
        guard !log.events.contains(where: { $0.id == event.id }) else { return false }
        log.events.append(event)
        lastError = file.save(&log)
        return true
    }

    /// Records Mike's own rating.
    public func report(_ level: EnergyLevel, at date: Date = .now) {
        record(.selfReport(level, at: date, deviceID: deviceID))
    }

    /// Today's energy, or `nil` when unknown.
    public func reading(now: Date = .now, calendar: Calendar = .current) -> EnergyReading? {
        StateEngine.energy(events: log.active, now: now, calendar: calendar)
    }
}
