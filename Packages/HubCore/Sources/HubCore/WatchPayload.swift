import Foundation

// Issue #160. The watch computes nothing: the iPhone sends what it already wrote for its own widgets,
// plus the wardrobe and bedtime HAKU's drawing needs. Health, places and Screen Time stay on the iPhone.
/// What the iPhone sends the Apple Watch so it can draw HAKU.
public struct WatchPayload: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    /// The key the payload's JSON travels under in a WatchConnectivity dictionary.
    public static let messageKey = "payload"

    public var schemaVersion: Int
    public var snapshot: WidgetSnapshot
    public var wardrobe: Wardrobe
    public var bedtime: BedtimeSchedule
    public var persona: Persona

    public init(
        snapshot: WidgetSnapshot,
        wardrobe: Wardrobe = Wardrobe(),
        bedtime: BedtimeSchedule = .standard,
        persona: Persona = .haku
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.snapshot = snapshot
        self.wardrobe = wardrobe
        self.bedtime = bedtime
        self.persona = persona
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, snapshot, wardrobe, bedtime, persona }

    /// Decodes the payload; a missing wardrobe, bedtime or persona falls back to the defaults.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        snapshot = try values.decode(WidgetSnapshot.self, forKey: .snapshot)
        wardrobe = (try? values.decodeIfPresent(Wardrobe.self, forKey: .wardrobe)) ?? Wardrobe()
        bedtime = (try? values.decodeIfPresent(BedtimeSchedule.self, forKey: .bedtime)) ?? .standard
        persona = (try? values.decodeIfPresent(Persona.self, forKey: .persona)) ?? .haku
    }

    /// Whether this payload should replace `stored`: it is not older. Transfers can arrive out of order.
    public func replaces(_ stored: WatchPayload?) -> Bool {
        guard let stored else { return true }
        return snapshot.updatedAt >= stored.snapshot.updatedAt
    }

    /// Whether `other` draws the same watch face: equal apart from the write time and the work time.
    public func drawsLike(_ other: WatchPayload) -> Bool {
        var mine = self
        var theirs = other
        // Both change on every iPhone write while nothing on the watch face does.
        mine.snapshot.updatedAt = .distantPast
        theirs.snapshot.updatedAt = .distantPast
        mine.snapshot.workedToday = nil
        theirs.snapshot.workedToday = nil
        return mine == theirs
    }

    /// When the watch widgets redraw: the iPhone widgets' times for this snapshot.
    public func timelineDates(after date: Date, calendar: Calendar = .current) -> [Date] {
        WidgetSnapshot.timelineDates(after: date, bedtime: bedtime, needTimes: snapshot.needTimes, calendar: calendar)
    }

    /// The payload as a WatchConnectivity dictionary, `nil` when it can't be encoded.
    public var message: [String: Any]? {
        guard let data = try? HubJSON.encoder().encode(self) else { return nil }
        return [Self.messageKey: data]
    }

    /// The payload in a WatchConnectivity dictionary, `nil` when there is none or it can't be read.
    public init?(message: [String: Any]) {
        guard let data = message[Self.messageKey] as? Data,
            let payload = try? HubJSON.decoder().decode(WatchPayload.self, from: data)
        else { return nil }
        self = payload
    }

    /// The payload stored at `url`, or `nil` when there is none or it can't be decoded.
    public static func read(from url: URL?) -> WatchPayload? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? HubJSON.decoder().decode(WatchPayload.self, from: data)
    }

    /// Writes the payload to `url`, replacing what was there.
    /// - Throws: file system or encoding errors.
    public func write(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try HubJSON.encoder().encode(self).write(to: url, options: .atomic)
    }
}
