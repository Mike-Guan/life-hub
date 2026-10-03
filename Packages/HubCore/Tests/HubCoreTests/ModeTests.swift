import Foundation
import Testing

@testable import HubCore

@Suite struct ModeTests {
    @Test func everyModeHasDistinctLabels() {
        let modes = Mode.allCases
        #expect(Set(modes.map(\.title)).count == modes.count)
        #expect(Set(modes.map(\.code)).count == modes.count)
        #expect(modes.allSatisfy { !$0.tagline.isEmpty })
        #expect(modes.map(\.id) == modes.map(\.rawValue))
    }

    @Test func bedtimeEncodesAsItsName() throws {
        let data = try JSONEncoder().encode([Bedtime.off, .on])
        #expect(String(decoding: data, as: UTF8.self) == #"["off","on"]"#)
        #expect(try JSONDecoder().decode([Bedtime].self, from: data) == [.off, .on])
    }

    @MainActor @Test func liveStoreKeepsItsDeviceID() throws {
        let suite = "lifehub-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = ModeStore.live(defaults: defaults)
        let second = ModeStore.live(defaults: defaults)
        #expect(!first.deviceID.isEmpty)
        #expect(first.deviceID == second.deviceID)
    }

    @MainActor @Test func previewStoreOnlyHasPastChanges() {
        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: .now) ?? .now
        let store = ModeStore.preview(now: noon)
        #expect(store.current == .work)
        #expect(store.log.changes.allSatisfy { $0.at <= noon })
    }
}
