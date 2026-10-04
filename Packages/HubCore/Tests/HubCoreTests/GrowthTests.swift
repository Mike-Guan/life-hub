import Foundation
import Testing

@testable import HubCore

@MainActor
@Suite struct GrowthTests {
    let at = Date(timeIntervalSince1970: 1_790_000_000)

    func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "lifehub-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "can-ledger.json")
    }

    func item(_ id: String) throws -> ShopItem {
        try #require(ShopItem.item(id))
    }

    @Test func aWinCountsOncePerSource() {
        let store = GrowthStore(fileURL: nil, deviceID: "t")
        store.record(.gym, source: "workout-1", at: at)
        store.record(.gym, source: "workout-1", at: at.addingTimeInterval(60))
        store.record(.daylight, source: "2026-10-04", at: at)
        #expect(store.ledger.balance == Win.gym.cans + Win.daylight.cans)
        #expect(store.ledger.count(.gym) == 1)
    }

    func workout(_ id: String, _ kind: WorkoutSummary.Kind, minutes: Double, meters: Double? = nil) -> WorkoutSummary {
        WorkoutSummary(id: id, kind: kind, start: at, end: at + minutes * 60, meters: meters)
    }

    @Test func workoutsEarnTheWinsHakuCheers() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        let workouts = [
            workout("box", .boxing, minutes: 60),
            workout("box-short", .boxing, minutes: 10),
            workout("run", .running, minutes: 30, meters: 5200),
            workout("jog", .running, minutes: 15, meters: 2000),
            workout("lift-1", .strength, minutes: 45),
            workout("lift-2", .strength, minutes: 25),
            workout("lift-short", .strength, minutes: 5),
            workout("walk", .other, minutes: 90),
        ]
        let wins = Win.wins(in: workouts, calendar: calendar)
        #expect(wins.map(\.win) == [.boxing, .run5k, .gym, .gym])
        let boxingSource = Win.boxing.source(at: at, calendar: calendar)
        #expect(wins[0] == EarnedWin(win: .boxing, source: boxingSource, at: at + 3600))
        // Two lifts on one day share a source, so the ledger counts the gym once.
        #expect(wins[2].source == wins[3].source)
        let store = GrowthStore(fileURL: nil, deviceID: "t")
        for win in wins { store.record(win.win, source: win.source, at: win.at) }
        #expect(store.ledger.count(.gym) == 1)
    }

    @Test func boxingEarnsOnceAWeekAndTheRestOnceADay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        let day: TimeInterval = 24 * 60 * 60
        let boxing = { Win.boxing.source(at: $0, calendar: calendar) }
        #expect(Win.boxing.cap == .week)
        #expect(boxing(at) != boxing(at + 7 * day))
        for win in Win.allCases where win != .boxing {
            #expect(win.cap == .day)
            #expect(win.source(at: at, calendar: calendar) != win.source(at: at + day, calendar: calendar))
        }
        #expect(Win.run5k.source(at: at, calendar: calendar) != Win.gym.source(at: at, calendar: calendar))
    }

    @Test func buyingSpendsCansOnce() throws {
        let store = GrowthStore(fileURL: nil, deviceID: "t")
        let plant = try item("room.plant")
        #expect(throws: GrowthStore.BuyError.notEnoughCans) { try store.buy(plant, at: at) }

        for day in 0..<4 { store.record(.boxing, source: "day-\(day)", at: at) }
        try store.buy(plant, at: at)
        #expect(store.ledger.balance == 4 * Win.boxing.cans - (plant.price ?? 0))
        #expect(store.ledger.owned == ["room.plant"])
        #expect(throws: GrowthStore.BuyError.alreadyOwned) { try store.buy(plant, at: at) }
        #expect(throws: GrowthStore.BuyError.notForSale) { try store.buy(try item("gloves.gold"), at: at) }
    }

    @Test func keepsakesAreGrantedOnceAtTheirCount() throws {
        let store = GrowthStore(fileURL: nil, deviceID: "t")
        let headband = try item("keepsake.headband.runner")
        #expect(store.remaining(for: headband) == 4)
        for run in 0..<3 { #expect(store.record(.run5k, source: "run-\(run)", at: at).isEmpty) }
        #expect(store.remaining(for: headband) == 1)
        #expect(store.record(.run5k, source: "run-3", at: at) == [headband])
        #expect(store.remaining(for: headband) == nil)
        #expect(store.record(.run5k, source: "run-4", at: at).isEmpty)
        #expect(store.ledger.owned == ["keepsake.headband.runner"])
        // Keepsakes are free.
        #expect(store.ledger.balance == 5 * Win.run5k.cans)
        #expect(store.remaining(for: try item("room.plant")) == nil)
    }

    @Test func ledgerPersistsAndKeepsUnreadableEntries() throws {
        let url = tempURL()
        let store = GrowthStore(fileURL: url, deviceID: "t")
        store.record(.gotUp, source: "invite-1", at: at)
        #expect(store.lastError == nil)

        // A newer build's entry this build can't read must survive a save.
        var json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var entries = try #require(json["entries"] as? [[String: Any]])
        entries.append(["id": UUID().uuidString, "kind": "future", "at": "2026-10-04T00:00:00Z"])
        json["entries"] = entries
        try JSONSerialization.data(withJSONObject: json).write(to: url)

        let reloaded = GrowthStore(fileURL: url, deviceID: "t")
        #expect(reloaded.ledger.owned == ["celebrate.up"])
        #expect(reloaded.ledger.unreadable.count == 1)
        reloaded.record(.daylight, source: "day-1", at: at)
        let again = GrowthStore(fileURL: url, deviceID: "t")
        #expect(again.ledger.unreadable.count == 1)
        #expect(again.ledger.balance == Win.gotUp.cans + Win.daylight.cans)
    }

    @Test func entryDecodingFillsDefaults() throws {
        let json = #"{"id":"\#(UUID().uuidString)","kind":"earned","at":"2026-10-04T00:00:00Z","win":"gym"}"#
        let entry = try HubJSON.decoder().decode(CanEntry.self, from: Data(json.utf8))
        #expect(entry.cans == 0)
        #expect(entry.updatedBy == "unknown")
        #expect(entry.createdAt == entry.at)
    }

    @Test func derivedIDsAreStable() {
        #expect(UUID.derived(from: "a") == UUID.derived(from: "a"))
        #expect(UUID.derived(from: "a") != UUID.derived(from: "b"))
    }

    @Test func wardrobeEquipsOnePerSlotAndPersists() throws {
        let suite = "lifehub-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var wardrobe = Wardrobe.stored(in: defaults)
        #expect(wardrobe.equipped.isEmpty)
        wardrobe.equip(try item("gloves.pink"))
        wardrobe.equip(try item("gloves.gold"))
        wardrobe.equip(try item("room.plant"))
        wardrobe.clear(.room)
        wardrobe.store(in: defaults)
        #expect(Wardrobe.stored(in: defaults).equipped == [.gloves: "gloves.gold"])
    }

    @Test func catalogIDsAreUnique() {
        #expect(Set(ShopItem.catalog.map(\.id)).count == ShopItem.catalog.count)
        #expect(ShopItem.catalog.allSatisfy { ($0.price == nil) != ($0.keepsake == nil) })
    }
}
