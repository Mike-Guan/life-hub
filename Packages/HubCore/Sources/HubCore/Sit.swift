import Foundation

/// One Apple Watch stand hour.
public struct StandHour: Equatable, Sendable {
    /// When the hour starts.
    public var start: Date
    /// Whether Mike stood for a minute in it.
    public var stood: Bool

    public init(start: Date, stood: Bool) {
        self.start = start
        self.stood = stood
    }
}

// Issue #126. Only these two times leave the stand hours, so nothing from HealthKit is kept.
/// What HAKU knows about sitting, worked out by the app from the stand hours and read by the widgets.
public struct SitState: Codable, Equatable, Sendable {
    /// When the last stand hours were read.
    public var checkedAt: Date
    /// Start of the stretch of idle stand hours that makes HAKU stiff, `nil` when there is none.
    public var stiffSince: Date?
    /// Start of the hour Mike stood after being stiff, `nil` when he didn't.
    public var stoodAt: Date?

    public init(checkedAt: Date, stiffSince: Date? = nil, stoodAt: Date? = nil) {
        self.checkedAt = checkedAt
        self.stiffSince = stiffSince
        self.stoodAt = stoodAt
    }

    static let defaultsKey = "sitState"

    /// The state saved in `defaults`, or `nil` when none is saved or it can't be read.
    public static func stored(in defaults: UserDefaults) -> SitState? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(SitState.self, from: data)
    }

    /// Saves the state in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }

    /// Whether HAKU is stiff at `date` in `mode`: only in work and 副业, and only while the reading is fresh.
    public func isStiff(mode: Mode?, at date: Date) -> Bool {
        guard let stiffSince, mode == .work || mode == .money else { return false }
        return stiffSince <= date && date < checkedAt.addingTimeInterval(SitEngine.freshFor)
    }

    /// The stretch after Mike stood up from being stiff, while it is recent; its id is the hour he stood.
    public func stretched(at date: Date) -> CompanionEvent? {
        guard let stoodAt, stoodAt <= date, date < stoodAt.addingTimeInterval(SitEngine.stretchLasts) else {
            return nil
        }
        return .stretched(id: stoodAt.ISO8601Format())
    }
}

/// Rules for sitting too long. T0, no models.
public enum SitEngine {
    /// Idle stand hours in a row that make HAKU stiff.
    public static let idleHours = 2
    // The Watch syncs late, more so with the phone locked; older data is too unsure to react to.
    /// How long a reading counts, and how recent its last stand hour must be.
    public static let freshFor: TimeInterval = 2 * 60 * 60
    /// How long after the stand hour HAKU still stretches when the app opens.
    public static let stretchLasts: TimeInterval = 2 * 60 * 60

    /// The state from today's stand `hours` at `now`.
    /// - Returns: a state with no times when there is no recent stand hour (no Watch, or not synced).
    public static func state(_ hours: [StandHour], now: Date) -> SitState {
        var state = SitState(checkedAt: now)
        let done = hours.filter { $0.start.addingTimeInterval(60 * 60) <= now }.sorted { $0.start < $1.start }
        guard let last = done.last, last.start.addingTimeInterval(60 * 60 + freshFor) > now else { return state }
        // A stand hour is only recorded while the Watch is worn, so a gap breaks the stretch.
        var idle: [StandHour] = []
        var next = last.stood ? last.start : last.start.addingTimeInterval(60 * 60)
        for hour in done.dropLast(last.stood ? 1 : 0).reversed() {
            guard !hour.stood, next.timeIntervalSince(hour.start) == 60 * 60 else { break }
            idle.append(hour)
            next = hour.start
        }
        guard idle.count >= idleHours, let first = idle.last else { return state }
        if last.stood {
            state.stoodAt = last.start
        } else {
            state.stiffSince = first.start
        }
        return state
    }
}
