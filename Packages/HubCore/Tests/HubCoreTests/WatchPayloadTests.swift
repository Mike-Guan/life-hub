import Foundation
import Testing

@testable import HubCore

@Suite struct WatchPayloadTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    func payload() -> WatchPayload {
        let snapshot = WidgetSnapshot(
            mode: .work,
            since: date(7, 9),
            energy: .okay,
            line: "上班中",
            updatedAt: date(7, 10)
        )
        return WatchPayload(snapshot: snapshot, wardrobe: Wardrobe(equipped: [.gloves: "gloves.gold"]))
    }

    @Test func travelsThroughAMessage() throws {
        let message = try #require(payload().message)
        #expect(WatchPayload(message: message) == payload())
    }

    @Test func anOlderPayloadNeverReplacesANewerOne() {
        let newer = payload()
        var older = payload()
        older.snapshot.mode = .boxing
        older.snapshot.updatedAt = date(7, 9, 59)
        #expect(newer.replaces(nil))
        #expect(newer.replaces(older))
        #expect(!older.replaces(newer))
        #expect(newer.replaces(newer))
    }

    @Test func ignoresAnEmptyOrUnreadableMessage() {
        #expect(WatchPayload(message: [:]) == nil)
        #expect(WatchPayload(message: [WatchPayload.messageKey: Data("{}".utf8)]) == nil)
        #expect(WatchPayload(message: [WatchPayload.messageKey: "text"]) == nil)
    }

    @Test func missingWardrobeAndBedtimeUseDefaults() throws {
        let snapshot = try HubJSON.encoder().encode(payload().snapshot)
        let json = #"{"snapshot":"# + String(decoding: snapshot, as: UTF8.self) + "}"
        let decoded = try HubJSON.decoder().decode(WatchPayload.self, from: Data(json.utf8))
        #expect(decoded.wardrobe == Wardrobe())
        #expect(decoded.bedtime == .standard)
        #expect(decoded.persona == .haku)
        #expect(decoded.snapshot == payload().snapshot)
        #expect(decoded.cards == .legacy(for: .haku))
    }

    @Test func showsTheUsersCardNames() throws {
        var cards = ModeCards(identity: .art)
        cards.rename(.work, to: "School")
        let payload = WatchPayload(snapshot: payload().snapshot, persona: .kuro, cards: cards)
        let message = try #require(payload.message)
        let decoded = try #require(WatchPayload(message: message))
        #expect(decoded.title(for: .work) == "School")
        #expect(decoded.title(for: .boxing) == "画画手作")
        #expect(decoded.title(for: .chill) == Mode.chill.title(for: .kuro))
    }

    @Test func anOldIPhoneKeepsTheCharactersOwnNames() {
        let haku = WatchPayload(snapshot: payload().snapshot)
        let kuro = WatchPayload(snapshot: payload().snapshot, persona: .kuro)
        for mode in Mode.allCases {
            #expect(haku.title(for: mode) == mode.title(for: .haku))
            #expect(kuro.title(for: mode) == mode.title(for: .kuro))
        }
    }

    @Test func cutsANameTooWideForTheClockRow() {
        var cards = ModeCards()
        cards.names[Mode.work.rawValue] = "一二三四五"
        cards.names[Mode.chill.rawValue] = "Afterwork"
        let payload = WatchPayload(snapshot: payload().snapshot, cards: cards)
        #expect(payload.title(for: .work) == "一二三四")
        #expect(payload.title(for: .chill) == "Afterwor")
        for mode in Mode.allCases {
            #expect(ModeCards.width(of: payload.title(for: mode)) <= ModeCards.nameWidth)
        }
    }

    @Test func aRenamedCardRedrawsTheWatchFace() {
        var cards = ModeCards.legacy(for: .haku)
        cards.rename(.work, to: "工作")
        #expect(!WatchPayload(snapshot: payload().snapshot, cards: cards).drawsLike(payload()))
    }

    @Test func readsBackWhatItWrote() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "watch-\(UUID().uuidString)/watch-payload.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        #expect(WatchPayload.read(from: url) == nil)
        #expect(WatchPayload.read(from: nil) == nil)
        try payload().write(to: url)
        #expect(WatchPayload.read(from: url) == payload())
    }

    @Test func drawsLikeIgnoresWriteTimeAndWorkTime() {
        var later = payload()
        later.snapshot.updatedAt = date(7, 11)
        later.snapshot.workedToday = 3600
        #expect(payload().drawsLike(later))
        var moved = payload()
        moved.snapshot.mode = .chill
        #expect(!payload().drawsLike(moved))
        var dressed = payload()
        dressed.wardrobe = Wardrobe()
        #expect(!payload().drawsLike(dressed))
    }

    @Test func redrawsWhenTheIPhoneWidgetsDo() {
        let now = date(7, 12)
        let expected = WidgetSnapshot.timelineDates(
            after: now,
            bedtime: .standard,
            needTimes: payload().snapshot.needTimes,
            calendar: calendar
        )
        #expect(payload().timelineDates(after: now, calendar: calendar) == expected)
    }

    @Test func carriesThePersona() throws {
        let sent = WatchPayload(snapshot: payload().snapshot, persona: .kuro)
        let message = try #require(sent.message)
        #expect(WatchPayload(message: message)?.persona == .kuro)
    }

    @Test func playsTheFirstSceneWhenReadBeforeIt() {
        let coding = HomeScene(moment: .vibeCoding)
        let late = HomeScene(moment: .lateCoding)
        var sent = payload()
        sent.scenes = [TimedScene(from: date(7, 20), scene: coding), TimedScene(from: date(7, 22), scene: late)]
        // The watch draws at the start of the minute, seconds before the iPhone's first scene.
        #expect(sent.scene(at: date(7, 19, 59)) == coding)
        #expect(sent.scene(at: date(7, 21)) == coding)
        #expect(sent.scene(at: date(7, 23)) == late)
        #expect(payload().scene(at: date(7, 21)) == nil)
    }
}
