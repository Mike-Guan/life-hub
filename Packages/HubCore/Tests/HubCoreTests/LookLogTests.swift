import Foundation
import Testing

@testable import HubCore

@MainActor
@Suite struct LookLogTests {
    let at = Date(timeIntervalSince1970: 1_790_000_000)
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func folder() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "lifehub-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    func item(_ id: String) throws -> ShopItem {
        try #require(ShopItem.item(id))
    }

    var headband: Wardrobe { Wardrobe(equipped: [.headband: "headband.cyan"]) }

    @Test func aGrantedKeepsakeKeepsTheLookItArrivedIn() throws {
        let store = GrowthStore(fileURL: nil, deviceID: "t")
        var asked: [(Persona, Date)] = []
        store.lookAt = { persona, date in
            asked.append((persona, date))
            return Look(mode: .boxing, wardrobe: headband, card: .boxing)
        }
        for week in 0..<10 { store.record(.boxing, source: "box-\(week)", at: at, card: .boxing) }
        let grant = try #require(store.ledger.entries.first { $0.kind == .granted })
        let look = try #require(store.looks.look(for: grant.id))
        #expect(look == Look(mode: .boxing, wardrobe: headband, card: .boxing))
        #expect(store.looks.look(of: "gloves.gold", persona: .haku) == look)
        // Only the item asks for a look; earning cans keeps none.
        #expect(asked.count == 1)
        #expect(store.looks.snapshots.count == 1)
    }

    @Test func aPurchaseKeepsTheLookOncePerItem() throws {
        let store = GrowthStore(fileURL: nil, deviceID: "t")
        store.lookAt = { _, _ in Look(mode: .chill, wardrobe: Wardrobe(), card: nil) }
        for day in 0..<4 { store.record(.gym, source: "gym-\(day)", at: at) }
        let band = try item("headband.cyan")
        try store.buy(band, at: at)
        #expect(throws: GrowthStore.BuyError.alreadyOwned) { try store.buy(band, at: at) }
        #expect(store.looks.snapshots.count == 1)
        #expect(store.looks.look(of: band.id, persona: .haku)?.mode == .chill)
    }

    @Test func noLookIsKeptWhenItIsNotKnown() throws {
        let unset = GrowthStore(fileURL: nil, deviceID: "t")
        for week in 0..<10 { unset.record(.boxing, source: "box-\(week)", at: at, card: .boxing) }
        #expect(unset.looks.snapshots.isEmpty)
        let unknown = GrowthStore(fileURL: nil, deviceID: "t")
        unknown.lookAt = { _, _ in nil }
        for week in 0..<10 { unknown.record(.boxing, source: "box-\(week)", at: at, card: .boxing) }
        #expect(unknown.looks.snapshots.isEmpty)
    }

    @Test func theLookIsTodaysModeAndWardrobe() {
        let log = ModeLog(changes: [
            ModeChange(mode: .work, at: at - 3600, deviceID: "t"),
            ModeChange(mode: .boxing, at: at - 600, deviceID: "t"),
            ModeChange(mode: .chill, at: at + 600, deviceID: "t"),
        ])
        let look = Look.at(at, log: log, wardrobe: headband, card: .boxing, now: at + 1200, calendar: calendar)
        #expect(look == Look(mode: .boxing, wardrobe: headband, card: .boxing))
        // A win back-filled from another day, or from the future, gets no look: the wardrobe has no history.
        let yesterday = at - 86_400
        #expect(Look.at(yesterday, log: log, wardrobe: headband, card: nil, now: at, calendar: calendar) == nil)
        #expect(Look.at(at + 60, log: log, wardrobe: headband, card: nil, now: at, calendar: calendar) == nil)
        // Before any mode change the mode is unknown, not guessed.
        let empty = Look.at(at, log: ModeLog(), wardrobe: Wardrobe(), card: nil, now: at, calendar: calendar)
        #expect(empty == Look(mode: nil, wardrobe: Wardrobe(), card: nil))
    }

    @Test func looksSurviveARelaunchAndAreErasedWithTheLedger() throws {
        let container = HubContainer(folder: folder())
        let store = GrowthStore(fileURL: container.canLedgerURL, lookURL: container.lookLogURL, deviceID: "t")
        store.lookAt = { _, _ in Look(mode: .boxing, wardrobe: Wardrobe(), card: .boxing) }
        for week in 0..<10 { store.record(.boxing, source: "box-\(week)", at: at, card: .boxing) }
        #expect(store.lastError == nil)
        let reopened = GrowthStore(fileURL: container.canLedgerURL, lookURL: container.lookLogURL, deviceID: "t")
        #expect(reopened.looks == store.looks)
        #expect(LookLog.read(from: container.lookLogURL) == store.looks)
        reopened.eraseAll()
        #expect(reopened.looks.snapshots.isEmpty)
        let lookPath = try #require(container.lookLogURL).path
        #expect(!FileManager.default.fileExists(atPath: lookPath))
    }

    @Test func decodingToleratesMissingFieldsAndKeepsNewerRecords() throws {
        let json = """
            {"snapshots": [
              {"id": "6F1D2A4C-3B5E-4C7D-8E9F-0A1B2C3D4E5F", "persona": "haku", "itemID": "gloves.gold"},
              {"id": "7F1D2A4C-3B5E-4C7D-8E9F-0A1B2C3D4E5F", "persona": "someoneNew", "itemID": "x",
               "mode": "work"},
              {"id": "8F1D2A4C-3B5E-4C7D-8E9F-0A1B2C3D4E5F", "persona": "kuro", "itemID": "y",
               "mode": "flying", "card": "chess", "wardrobe": {"equipped": {}}}
            ]}
            """
        let log = try HubJSON.decoder().decode(LookLog.self, from: Data(json.utf8))
        #expect(log.snapshots.count == 2)
        #expect(log.unreadable.count == 1)
        let first = log.snapshots[0]
        #expect(first.look == Look(mode: nil, wardrobe: Wardrobe(), card: nil))
        #expect(first.updatedBy == "unknown")
        // A mode or card from a newer build reads as unknown and is written back unchanged.
        let newer = log.snapshots[1]
        #expect(newer.look.mode == nil && newer.look.card == nil)
        let again = try HubJSON.decoder().decode(LookLog.self, from: HubJSON.encoder().encode(log))
        #expect(again.unreadable.count == 1)
        #expect(again.snapshots[1].look.modeName == "flying")
        #expect(again.snapshots[1].look.cardName == "chess")
    }

    @Test func aDeletedSnapshotIsNotShown() {
        var snapshot = LookSnapshot(
            entry: UUID(),
            persona: .haku,
            itemID: "gloves.gold",
            look: Look(mode: .boxing, wardrobe: Wardrobe(), card: nil),
            at: at,
            deviceID: "t"
        )
        snapshot.deletedAt = at
        let log = LookLog(snapshots: [snapshot])
        #expect(log.look(for: snapshot.id) == nil)
        #expect(log.look(of: "gloves.gold", persona: .haku) == nil)
    }
}
