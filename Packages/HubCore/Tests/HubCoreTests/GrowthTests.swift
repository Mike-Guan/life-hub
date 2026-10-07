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

    @Test func onlyBoxingRunningAndStrengthEarn() {
        let earning: Set<WorkoutSummary.Kind> = [.boxing, .running, .strength]
        let workouts = WorkoutSummary.Kind.allCases.map { workout($0.rawValue, $0, minutes: 90, meters: 10_000) }
        let wins = Win.wins(in: workouts)
        #expect(wins.count == earning.count)
        let others = workouts.filter { !earning.contains($0.kind) }
        #expect(others.count == WorkoutSummary.Kind.allCases.count - earning.count)
        #expect(Win.wins(in: others).isEmpty)
    }

    @Test func workoutKindsDecodeAndUnknownOnesBecomeOther() throws {
        let decoder = JSONDecoder()
        for kind in WorkoutSummary.Kind.allCases {
            let data = try JSONEncoder().encode(kind)
            #expect(try decoder.decode(WorkoutSummary.Kind.self, from: data) == kind)
        }
        let unknown = Data(#""skydiving""#.utf8)
        #expect(try decoder.decode(WorkoutSummary.Kind.self, from: unknown) == .other)
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
        #expect(store.ledger.ownedAt(headband.id) == nil)
        let fourth = at.addingTimeInterval(3_600)
        #expect(store.record(.run5k, source: "run-3", at: fourth) == [headband])
        #expect(store.ledger.ownedAt(headband.id) == fourth)
        #expect(store.remaining(for: headband) == nil)
        #expect(store.record(.run5k, source: "run-4", at: at).isEmpty)
        #expect(store.ledger.owned == ["keepsake.headband.runner"])
        // KURO's runs start from zero.
        #expect(store.remaining(for: try item("kuro.headband.sakura")) == 4)
        // Keepsakes are free.
        #expect(store.ledger.balance == 5 * Win.run5k.cans)
        #expect(store.remaining(for: try item("room.plant")) == nil)
    }

    @Test func newItemsAreUnboxedOnce() throws {
        let store = GrowthStore(fileURL: nil, deviceID: "t")
        for run in 0..<4 { store.record(.run5k, source: "run-\(run)", at: at.addingTimeInterval(Double(run))) }
        try store.buy(try item("room.plant"), at: at.addingTimeInterval(10))
        let pending = store.ledger.unboxings(seen: [])
        #expect(pending.compactMap(\.itemID) == ["keepsake.headband.runner", "room.plant"])
        let seen = Set(pending.prefix(1).map(\.id))
        #expect(store.ledger.unboxings(seen: seen).compactMap(\.itemID) == ["room.plant"])
    }

    @Test func eachCharacterUnboxesOnlyHerOwnItems() throws {
        let store = GrowthStore(fileURL: nil, deviceID: "t")
        for run in 0..<4 { store.record(.run5k, source: "run-\(run)", at: at.addingTimeInterval(Double(run))) }
        store.persona = .kuro
        for run in 4..<8 { store.record(.run5k, source: "run-\(run)", at: at.addingTimeInterval(Double(run))) }
        try store.buy(try item("kuro.room.flower"), at: at.addingTimeInterval(10))
        #expect(store.ledger.unboxings(seen: []).compactMap(\.itemID) == ["keepsake.headband.runner"])
        let kuro = store.ledger.unboxings(seen: [], persona: .kuro).compactMap(\.itemID)
        #expect(kuro == ["kuro.headband.sakura", "kuro.room.flower"])
    }

    @Test func eachCharacterHasHerOwnCans() throws {
        let store = GrowthStore(fileURL: nil, deviceID: "t")
        for day in 0..<4 { store.record(.boxing, source: "day-\(day)", at: at) }
        store.persona = .kuro
        // The same win can't pay KURO again after HAKU got it.
        store.record(.boxing, source: "day-0", at: at)
        store.record(.gym, source: "day-9", at: at)
        #expect(store.ledger.only(.haku).balance == 4 * Win.boxing.cans)
        #expect(store.ledger.only(.kuro).balance == Win.gym.cans)
        #expect(throws: GrowthStore.BuyError.notEnoughCans) { try store.buy(try item("kuro.room.flower"), at: at) }
        #expect(throws: GrowthStore.BuyError.notForSale) { try store.buy(try item("room.plant"), at: at) }
        store.persona = .haku
        try store.buy(try item("room.plant"), at: at)
        #expect(store.ledger.only(.haku).balance == 4 * Win.boxing.cans - 10)
        #expect(store.ledger.only(.kuro).balance == Win.gym.cans)
        #expect(store.ledger.only(.kuro).owned.isEmpty)
    }

    @Test func oldKeepsakesOfKuroStayHers() throws {
        let id = UUID().uuidString
        let json = #"{"id":"\#(id)","kind":"granted","at":"2026-10-04T00:00:00Z","itemID":"kuro.celebrate.spin"}"#
        let entry = try HubJSON.decoder().decode(CanEntry.self, from: Data(json.utf8))
        #expect(entry.persona == .kuro)
    }

    @Test func aKeepsakeIsNeverGrantedTwice() throws {
        let url = tempURL()
        let spin = try item("kuro.celebrate.spin")
        let grant = CanEntry(
            id: .derived(from: "granted:\(spin.id)"),
            kind: .granted,
            at: at,
            cans: 0,
            itemID: spin.id,
            persona: .haku,
            deviceID: "t"
        )
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try HubJSON.encoder().encode(CanLedger(entries: [grant])).write(to: url)
        let store = GrowthStore(fileURL: url, deviceID: "t")
        store.persona = .kuro
        store.record(.gotUp, source: "invite-1", at: at)
        #expect(store.ledger.entries.filter { $0.id == grant.id }.count == 1)
    }

    @Test func entriesWithoutACharacterAreHakus() throws {
        let json = #"{"id":"\#(UUID().uuidString)","kind":"earned","at":"2026-10-04T00:00:00Z","win":"gym","cans":3}"#
        let entry = try HubJSON.decoder().decode(CanEntry.self, from: Data(json.utf8))
        #expect(entry.persona == .haku)
        let ledger = CanLedger(entries: [entry])
        #expect(ledger.only(.haku).balance == 3)
        #expect(ledger.only(.kuro).balance == 0)
        var kuro = entry
        kuro.persona = .kuro
        let decoded = try HubJSON.decoder().decode(CanEntry.self, from: HubJSON.encoder().encode(kuro))
        #expect(decoded.persona == .kuro)
    }

    @Test func kuroHasHerOwnCatalogAtHakusPrices() {
        let haku = ShopItem.catalog(for: .haku)
        let kuro = ShopItem.catalog(for: .kuro)
        #expect(haku.count + kuro.count == ShopItem.catalog.count)
        #expect(kuro.compactMap(\.price).sorted() == haku.compactMap(\.price).sorted())
        #expect(kuro.compactMap(\.keepsake).map(\.win) == [.gotUp, .run5k, .boxing])
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
        // KURO's wardrobe is kept apart from HAKU's.
        #expect(Wardrobe.stored(in: defaults, persona: .kuro) == Wardrobe())
        Wardrobe(equipped: [.gloves: "kuro.racket.gold"]).store(in: defaults, persona: .kuro)
        #expect(Wardrobe.stored(in: defaults, persona: .kuro).equipped == [.gloves: "kuro.racket.gold"])
        #expect(Wardrobe.stored(in: defaults).equipped == [.gloves: "gloves.gold"])
    }

    @Test func catalogIDsAreUnique() {
        #expect(Set(ShopItem.catalog.map(\.id)).count == ShopItem.catalog.count)
        #expect(ShopItem.catalog.allSatisfy { ($0.price == nil) != ($0.keepsake == nil) })
    }
}
