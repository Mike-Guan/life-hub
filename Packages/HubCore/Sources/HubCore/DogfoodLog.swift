import Foundation

// PRD section 19: during the 2 to 4 weeks of use, wrong geofence switches and unsure calls should be
// visible afterwards. Debug builds only, stored on the device, never shown in the app.
/// A short local list of automatic decisions, newest last.
public struct DogfoodLog: Codable, Equatable, Sendable {
    /// One automatic decision.
    public struct Entry: Codable, Equatable, Sendable {
        public var at: Date
        /// What made the decision, such as "geofence" or "focus".
        public var kind: String
        public var detail: String

        public init(at: Date, kind: String, detail: String) {
            self.at = at
            self.kind = kind
            self.detail = detail
        }
    }

    static let defaultsKey = "dogfoodLog"
    /// How many entries are kept; older ones are dropped.
    public static let limit = 500

    public var entries: [Entry]

    public init(entries: [Entry] = []) {
        self.entries = entries
    }

    /// Adds `entry`, dropping the oldest beyond `limit`.
    public mutating func append(_ entry: Entry) {
        entries.append(entry)
        if entries.count > Self.limit { entries.removeFirst(entries.count - Self.limit) }
    }

    /// The log saved in `defaults`, or an empty one when nothing is saved or it can't be read.
    public static func stored(in defaults: UserDefaults) -> DogfoodLog {
        guard let data = defaults.data(forKey: defaultsKey) else { return DogfoodLog() }
        return (try? JSONDecoder().decode(DogfoodLog.self, from: data)) ?? DogfoodLog()
    }

    /// Saves the log in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }
}
