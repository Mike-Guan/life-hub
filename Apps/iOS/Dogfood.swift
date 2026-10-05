import Foundation
import HubCore

/// Notes automatic decisions in the local dogfood log. Does nothing outside Debug builds.
enum Dogfood {
    /// Adds a line to the dogfood log.
    /// - Parameters:
    ///   - kind: what made the decision, such as "geofence".
    ///   - detail: what happened, in a few words.
    static func note(_ kind: String, _ detail: String, at date: Date = .now) {
        #if DEBUG
        var log = DogfoodLog.stored(in: AppGroup.defaults)
        log.append(DogfoodLog.Entry(at: date, kind: kind, detail: detail))
        log.store(in: AppGroup.defaults)
        #endif
    }
}
