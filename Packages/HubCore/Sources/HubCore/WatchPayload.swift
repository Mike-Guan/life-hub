import Foundation

// Issue #160. The watch computes nothing: the iPhone sends what it already wrote for its own widgets,
// plus the wardrobe and bedtime HAKU's drawing needs. Health, places and Screen Time stay on the iPhone.
/// What the iPhone sends the Apple Watch so it can draw HAKU.
public struct WatchPayload: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    /// The key the payload's JSON travels under in a WatchConnectivity dictionary.
    public static let messageKey = "payload"
    /// The key of the message the watch sends to ask the iPhone to re-check the mode.
    public static let checkKey = "check"

    public var schemaVersion: Int
    public var snapshot: WidgetSnapshot
    public var wardrobe: Wardrobe
    public var bedtime: BedtimeSchedule
    public var persona: Persona
    /// What the home card acts out over the next hours, so the watch plays the same scene.
    public var scenes: [TimedScene]
    /// The latest one-off from the iPhone (a workout, a Daily task done, coming back); it plays once by id.
    public var event: CompanionEvent?
    /// The user's cards, for the mode names; `nil` from builds before Issue #273.
    public var cards: ModeCards?

    public init(
        snapshot: WidgetSnapshot,
        wardrobe: Wardrobe = Wardrobe(),
        bedtime: BedtimeSchedule = .unset,
        persona: Persona = .haku,
        scenes: [TimedScene] = [],
        event: CompanionEvent? = nil,
        cards: ModeCards? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.snapshot = snapshot
        self.wardrobe = wardrobe
        self.bedtime = bedtime
        self.persona = persona
        self.scenes = scenes
        self.event = event
        self.cards = cards
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, snapshot, wardrobe, bedtime, persona, scenes, event, cards
    }

    /// Decodes the payload; anything missing besides the snapshot falls back to the defaults.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        snapshot = try values.decode(WidgetSnapshot.self, forKey: .snapshot)
        wardrobe = (try? values.decodeIfPresent(Wardrobe.self, forKey: .wardrobe)) ?? Wardrobe()
        bedtime = (try? values.decodeIfPresent(BedtimeSchedule.self, forKey: .bedtime)) ?? .unset
        persona = (try? values.decodeIfPresent(Persona.self, forKey: .persona)) ?? .haku
        scenes = (try? values.decodeIfPresent([TimedScene].self, forKey: .scenes)) ?? []
        event = try? values.decodeIfPresent(CompanionEvent.self, forKey: .event)
        cards = try? values.decodeIfPresent(ModeCards.self, forKey: .cards)
    }

    /// Whether this payload should replace `stored`: it is not older. Transfers can arrive out of order.
    public func replaces(_ stored: WatchPayload?) -> Bool {
        guard let stored else { return true }
        return snapshot.updatedAt >= stored.snapshot.updatedAt
    }

    /// Whether `other` draws the same watch face: equal apart from the write time, the work time and the
    /// event, which only the watch app plays, with the same scenes starting within a few minutes.
    public func drawsLike(_ other: WatchPayload) -> Bool {
        var mine = self
        var theirs = other
        // Both change on every iPhone write while nothing on the watch face does.
        mine.snapshot.updatedAt = .distantPast
        theirs.snapshot.updatedAt = .distantPast
        mine.snapshot.workedToday = nil
        theirs.snapshot.workedToday = nil
        mine.scenes = []
        theirs.scenes = []
        mine.event = nil
        theirs.event = nil
        return mine == theirs && Self.sameFaces(faceScenes, other.faceScenes)
    }

    // The face draws only these parts of a scene; the rest (cans, events, invites) plays in the watch app.
    // The first scene starts when the iPhone sends, so what plays from then on counts as already playing.
    /// The changes in what the watch face draws, each with when it starts; a start of `distantPast` is
    /// already playing when the iPhone sent.
    var faceScenes: [TimedScene] {
        var faces: [TimedScene] = []
        for timed in scenes {
            let scene = timed.scene
            let face = HomeScene(
                activity: scene.activity,
                moment: scene.moment,
                walking: scene.walking,
                bath: scene.bath,
                daily: scene.daily
            )
            guard face != (faces.last?.scene ?? HomeScene()) else { continue }
            faces.append(TimedScene(from: timed.from == scenes.first?.from ? .distantPast : timed.from, scene: face))
        }
        return faces
    }

    // The iPhone samples scenes every 5 minutes from when it sends, so the same change lands up to a step
    // apart in two sends. Redrawing for that alone would spend the watch face's daily reloads and
    // complication transfers.
    /// Whether `a` and `b` draw the same faces, each starting within `HomeSceneInputs.timelineStep`.
    static func sameFaces(_ a: [TimedScene], _ b: [TimedScene]) -> Bool {
        guard a.map(\.scene) == b.map(\.scene) else { return false }
        return zip(a, b).allSatisfy { abs($0.from.timeIntervalSince($1.from)) <= HomeSceneInputs.timelineStep }
    }

    // The first scene starts at the iPhone's clock when it sent them, and the watch draws at the start of
    // the minute, so a fresh payload is often read a few seconds before its first scene. The iPhone works
    // scenes out only `HomeSceneInputs.timelineHours` ahead; after that the last one is stale, and a stale
    // scene is worse than the plain mode (PM 动作展示总表 C8).
    /// The scene the watch plays at `date`: the one started by then, else the first; `nil` with no scenes
    /// or once they run out.
    public func scene(at date: Date) -> HomeScene? {
        guard let first = scenes.first,
            date <= first.from.addingTimeInterval(HomeSceneInputs.timelineHours * 60 * 60)
        else { return nil }
        return scenes.scene(at: date) ?? first.scene
    }

    /// When the watch widgets redraw: the iPhone widgets' times for this snapshot, when each scene starts, when
    /// the scenes run out and every 15 minutes, when the portrait changes its pose.
    public func timelineDates(after date: Date, calendar: Calendar = .current) -> [Date] {
        let end = scenes.first.map { $0.from.addingTimeInterval(HomeSceneInputs.timelineHours * 60 * 60) }
        let sceneTimes = scenes.map(\.from) + [end].compactMap { $0 }
        let times = snapshot.needTimes + sceneTimes + WidgetSnapshot.slotDates(after: date)
        return WidgetSnapshot.timelineDates(after: date, bedtime: bedtime, needTimes: times, calendar: calendar)
    }

    // An older iPhone build may send a name that doesn't fit the watch's clock row.
    /// The name of the card in `mode`'s slot, from the iPhone's cards or the character's defaults, cut to
    /// `ModeCards.nameWidth`.
    public func title(for mode: Mode) -> String {
        ModeCards.fitted((cards ?? .legacy(for: persona)).title(for: mode, persona: persona))
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
