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
