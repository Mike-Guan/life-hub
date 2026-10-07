import Foundation
import Observation

/// Owns the energy event log on this device. Single writer for `EnergyLog`.
@MainActor
@Observable
public final class EnergyStore {
    public private(set) var log: EnergyLog
    /// Last load or save failure, for the UI to show.
    public private(set) var lastError: String?
    /// Goes up on every write to the log, including a sleep import that updates its night in place.
    public private(set) var revision = 0
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
        revision += 1
        return true
    }

    /// Stores `night` as the sleep event for its night, replacing an earlier import of the same night.
    /// - Returns: `false` when the stored event already matches.
    @discardableResult
    public func record(_ night: SleepNight, now: Date = .now) -> Bool {
        guard let index = log.events.firstIndex(where: { $0.id == night.id }) else {
            var event = EnergyEvent.sleep(minutes: night.minutes, endedAt: night.endedAt, deviceID: deviceID)
            event.id = night.id
            return record(event)
        }
        var event = log.events[index]
        guard event.sleepMinutes != night.minutes || event.at != night.endedAt else { return false }
        event.sleepMinutes = night.minutes
        event.at = night.endedAt
        event.updatedAt = now
        event.updatedBy = deviceID
        log.events[index] = event
        lastError = file.save(&log)
        revision += 1
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

extension EnergyStore {
    /// The store the apps use, in `container` with this device's id from `defaults`.
    public static func live(
        in container: HubContainer = .applicationSupport(),
        defaults: UserDefaults = .standard
    ) -> EnergyStore {
        EnergyStore(fileURL: container.energyLogURL, deviceID: HubDevice.id(defaults: defaults))
    }
}
