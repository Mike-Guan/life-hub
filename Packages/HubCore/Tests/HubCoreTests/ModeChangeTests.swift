import Foundation
import Testing
@testable import HubCore

@Suite struct ModeChangeTests {
    let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    @Test func decodesMinimalRecordWithDefaults() throws {
        let json = #"{"id":"6F1C2B1E-2D7A-4C1A-9E43-1B2C3D4E5F60","mode":"boxing","at":"2026-10-02T10:00:00Z"}"#
        let change = try decoder.decode(ModeChange.self, from: Data(json.utf8))
        #expect(change.mode == .boxing)
        #expect(change.schemaVersion == 1)
        #expect(change.source == .inferred)
        #expect(change.createdAt == change.at)
        #expect(change.updatedAt == change.at)
        #expect(change.updatedBy == "unknown")
        #expect(change.deletedAt == nil)
    }

    @Test func unknownSourceCountsAsInferred() throws {
        let json = #"{"id":"6F1C2B1E-2D7A-4C1A-9E43-1B2C3D4E5F60","mode":"work","source":"telepathy","at":"2026-10-02T10:00:00Z"}"#
        let change = try decoder.decode(ModeChange.self, from: Data(json.utf8))
        #expect(change.source == .inferred)
    }

    @MainActor @Test func roundTripsThroughStoreEncoding() throws {
        let at = Date(timeIntervalSince1970: 1_790_000_000)
        let original = ModeChange(mode: .money, source: .manual, tag: "shoot", at: at, deviceID: "test")
        let data = try ModeStore.encoder.encode(original)
        let decoded = try ModeStore.decoder.decode(ModeChange.self, from: data)
        #expect(decoded == original)
    }

    @Test func logSkipsUnreadableRecords() throws {
        let json = """
        {"schemaVersion":1,"changes":[
          {"id":"6F1C2B1E-2D7A-4C1A-9E43-1B2C3D4E5F60","mode":"work","at":"2026-10-02T09:00:00Z"},
          {"id":"7F1C2B1E-2D7A-4C1A-9E43-1B2C3D4E5F60","mode":"sleep","at":"2026-10-02T23:00:00Z"}
        ]}
        """
        let log = try decoder.decode(ModeLog.self, from: Data(json.utf8))
        #expect(log.changes.map(\.mode) == [.work])
    }
}
