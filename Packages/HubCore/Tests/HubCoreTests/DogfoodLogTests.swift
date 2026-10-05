import Foundation
import Testing

@testable import HubCore

@Suite struct DogfoodLogTests {
    @Test func keepsTheNewestEntriesUpToTheLimit() {
        var log = DogfoodLog()
        for index in 0..<(DogfoodLog.limit + 2) {
            let at = Date(timeIntervalSince1970: Double(index))
            log.append(DogfoodLog.Entry(at: at, kind: "geofence", detail: "\(index)"))
        }
        #expect(log.entries.count == DogfoodLog.limit)
        #expect(log.entries.first?.detail == "2")
        #expect(log.entries.last?.detail == "\(DogfoodLog.limit + 1)")
    }

    @Test func roundTripsThroughDefaults() throws {
        let suite = "dogfood-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(DogfoodLog.stored(in: defaults).entries.isEmpty)
        var log = DogfoodLog()
        log.append(DogfoodLog.Entry(at: Date(timeIntervalSince1970: 0), kind: "focus", detail: "不切"))
        log.store(in: defaults)
        #expect(DogfoodLog.stored(in: defaults) == log)
    }
}
