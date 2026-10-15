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
            workout("unknown", .other, minutes: 90),
        ]
        let wins = Win.wins(in: workouts, identity: .boxing, calendar: calendar)
        #expect(wins.map(\.win) == [.boxing, .run5k, .exercise, .gym, .gym])
        let boxingSource = Win.boxing.source(at: at, calendar: calendar)
        #expect(wins[0] == EarnedWin(win: .boxing, source: boxingSource, at: at + 3600, card: .boxing))
        // Two lifts on one day share a source, so the ledger counts the gym once.
        #expect(wins[3].source == wins[4].source)
        let store = GrowthStore(fileURL: nil, deviceID: "t")
        for win in wins { store.record(win.win, source: win.source, at: win.at, card: win.card) }
        // The 30-minute run came first, so it took the day's shared gym and exercise can.
        #expect(store.ledger.count(.exercise) == 1)
        #expect(store.ledger.count(.gym) == 0)
        #expect(store.ledger.balance == Win.boxing.cans + Win.run5k.cans + Win.exercise.cans)
    }

    @Test func anyWorkoutOfHalfAnHourEarnsExerciseExceptWalks() {
        let workouts = WorkoutSummary.Kind.allCases.map { workout($0.rawValue, $0, minutes: 30) }
        let wins = Win.wins(in: workouts, identity: nil)
        let exercised = Set(wins.filter { $0.win == .exercise }.map(\.source))
        #expect(exercised.count == 1)
        let kinds = Set(WorkoutSummary.Kind.allCases).subtracting([.strength, .walking, .other])
        #expect(wins.filter { $0.win == .exercise }.count == kinds.count)
        #expect(wins.filter { $0.win == .gym }.count == 1)
        #expect(!wins.contains { $0.win == .boxing })
        #expect(Win.wins(in: [workout("short", .swimming, minutes: 29)], identity: nil).isEmpty)
    }

    @Test func theIdentityCardsWorkoutsEarnItsWinInsteadOfExercise() {
        for identity in IdentityKind.allCases {
            for kind in identity.workouts {
                let wins = Win.wins(in: [workout("w", kind, minutes: 30)], identity: identity)
                #expect(wins.map(\.win) == [.boxing])
                #expect(wins.first?.card == identity)
                #expect(Win.wins(in: [workout("w", kind, minutes: 29)], identity: identity).isEmpty)
            }
        }
        // Boxing with the tennis card is plain exercise.
        let boxed = Win.wins(in: [workout("w", .boxing, minutes: 60)], identity: .tennis)
        #expect(boxed.map(\.win) == [.exercise])
    }

    @Test func gymAndExerciseShareOneCanADay() {
        let store = GrowthStore(fileURL: nil, deviceID: "t")
        let gym = Win.gym.source(at: at)
        #expect(Win.exercise.source(at: at) == gym)
        store.record(.gym, source: gym, at: at)
        store.record(.exercise, source: Win.exercise.source(at: at), at: at)
        #expect(store.ledger.balance == Win.gym.cans)
        #expect(store.ledger.count(.gym) == 1)
        #expect(store.ledger.count(.exercise) == 0)
    }

    @Test func cardPlacesEarnTheCardsWinAndNeedACard() {
        let left = at + Win.visitMinimum
        let visit = Win.visit(.boxing, from: at, to: left, identity: .swimming)
        #expect(visit?.win == .boxing)
        #expect(visit?.card == .swimming)
        #expect(Win.visit(.boxing, from: at, to: left, identity: nil) == nil)
        #expect(Win.visit(.fitness, from: at, to: left, identity: nil)?.win == .gym)
        #expect(Win.visit(.fitness, from: at, to: left, identity: nil)?.card == nil)
    }

    @Test func theFitnessCardPaysAGymVisitAndAStrengthWorkoutOnce() {
        let store = GrowthStore(fileURL: nil, deviceID: "t")
        let left = at + Win.visitMinimum
        let visit = Win.visit(.fitness, from: at, to: left, identity: .fitness)
        #expect(visit?.win == .boxing)
        #expect(visit?.card == .fitness)
        let lifting = WorkoutSummary(id: "lift", kind: .strength, start: at, end: left)
        let earned = Win.wins(in: [lifting], identity: .fitness) + [visit].compactMap(\.self)
        for win in earned { store.record(win.win, source: win.source, at: win.at, card: win.card) }
        #expect(store.ledger.balance == Win.boxing.cans)
        #expect(Win.visit(.fitness, from: at, to: left, identity: .boxing)?.win == .gym)
    }

    @Test func goldKeepsakesCountOnlyTheirOwnCard() throws {
        let store = GrowthStore(fileURL: nil, deviceID: "t")
        let gloves = try item("gloves.gold")
        for week in 0..<9 { store.record(.boxing, source: "box-\(week)", at: at, card: .boxing) }
        for week in 0..<5 { store.record(.boxing, source: "swim-\(week)", at: at, card: .swimming) }
        #expect(store.remaining(for: gloves) == 1)
        #expect(store.ledger.count(.boxing) == 14)
        #expect(store.ledger.count(.boxing, card: .swimming) == 5)
        #expect(store.record(.boxing, source: "swim-5", at: at, card: .swimming).isEmpty)
        #expect(store.record(.boxing, source: "box-9", at: at, card: .boxing) == [gloves])
        // The second character's racket counts tennis only.
        store.persona = .kuro
        let racket = try item("kuro.racket.gold")
        #expect(store.remaining(for: racket) == 10)
        store.record(.boxing, source: "tennis-0", at: at, card: .tennis)
        #expect(store.remaining(for: racket) == 9)
    }

    @Test func entriesWithoutACardCountForTheCharactersOldCard() throws {
        let json = """
            {"id": "6F1D2A4C-3B5E-4C7D-8E9F-0A1B2C3D4E5F", "kind": "earned", "at": 0, "cans": 5,
             "win": "boxing", "persona": "kuro"}
            """
        let entry = try JSONDecoder().decode(CanEntry.self, from: Data(json.utf8))
        #expect(entry.cardName == nil)
        #expect(entry.card == .tennis)
        var haku = entry
        haku.persona = .haku
        #expect(haku.card == .boxing)
        var unknown = entry
        unknown.cardName = "fencing"
        #expect(unknown.card == nil)
        let saved = try JSONDecoder().decode(CanEntry.self, from: JSONEncoder().encode(unknown))
        #expect(saved.cardName == "fencing")
    }

    @Test func onlyIdentityWinsKeepTheirCard() {
        let gym = CanEntry.earned(.gym, source: "g", at: at, card: .boxing, deviceID: "t")
        #expect(gym.cardName == nil)
        let box = CanEntry.earned(.boxing, source: "b", at: at, card: .ski, deviceID: "t")
        #expect(box.cardName == "ski")
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
        #expect(Win.allCases.filter { $0.capGroup != $0 } == [.exercise])
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
        let plant = try item("room.plant")
        try store.buy(plant, at: at)
        #expect(store.ledger.only(.haku).balance == 4 * Win.boxing.cans - (plant.price ?? 0))
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
        // Identity card clothes and weekly items follow each character's own line, so those are left out.
        let haku = ShopItem.catalog(for: .haku).filter { $0.week == nil && $0.mode != .boxing }
        let kuro = ShopItem.catalog(for: .kuro).filter { $0.week == nil && $0.mode != .boxing }
        #expect(ShopItem.catalog(for: .haku).count + ShopItem.catalog(for: .kuro).count == ShopItem.catalog.count)
        #expect(kuro.compactMap(\.price).sorted() == haku.compactMap(\.price).sorted())
        #expect(kuro.filter(\.isDrawn).compactMap(\.keepsake).map(\.win) == [.gotUp, .run5k, .boxing])
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

    @Test func cardItemsShowOnlyWithTheirCard() {
        let boxing = ShopItem.catalog(for: .haku, card: .boxing).map(\.id)
        let tennis = ShopItem.catalog(for: .haku, card: .tennis).map(\.id)
        let none = ShopItem.catalog(for: .haku, card: nil).map(\.id)
        for id in ["gloves.pink", "room.bag", "gloves.gold"] {
            #expect(boxing.contains(id))
            #expect(!tennis.contains(id))
            #expect(!none.contains(id))
        }
        #expect(tennis.contains("room.plant") && none.contains("room.plant"))
        let kuro = ShopItem.catalog(for: .kuro, card: .boxing).map(\.id)
        #expect(!kuro.contains("kuro.bag.tennis") && !kuro.contains("kuro.racket.gold"))
        #expect(ShopItem.catalog(for: .kuro, card: .tennis).map(\.id).contains("kuro.bag.tennis"))
    }

    @Test func aKeepsakeBelongsToTheCardItCounts() {
        #expect(ShopItem.item("gloves.gold")?.card == .boxing)
        #expect(ShopItem.item("kuro.racket.gold")?.card == .tennis)
        #expect(ShopItem.item("keepsake.headband.runner")?.card == nil)
    }

    // QA S2: every character gets a whole shop, not a few items borrowed from HAKU.
    @Test func everyCharacterHasAWholeShop() {
        let haku = ShopItem.catalog(for: .haku).filter { $0.week == nil && $0.mode != .boxing }
        func keepsakes(_ items: [ShopItem]) -> [String] {
            items.compactMap(\.keepsake).map { "\($0.win.rawValue)×\($0.count)" }.sorted()
        }
        for persona in Persona.allCases {
            let items = ShopItem.catalog(for: persona).filter { $0.week == nil && $0.mode != .boxing }
            #expect(items.count == haku.count, "\(persona)")
            // Badges and hats are only sold as weekly items so far.
            #expect(Set(items.map(\.slot)) == Set(Slot.allCases).subtracting([.badge, .hat]), "\(persona)")
            #expect(keepsakes(items) == keepsakes(haku), "\(persona)")
        }
    }

    @Test func clothesAreWornOnePerModeAndASetReplacesTheTop() throws {
        var wardrobe = Wardrobe()
        let blazer = try #require(ShopItem.item("haku.top.work.blazer"))
        let raincoat = try #require(ShopItem.item("haku.set.work.raincoat"))
        let aloha = try #require(ShopItem.item("haku.top.chill.aloha"))
        wardrobe.equip(blazer)
        wardrobe.equip(aloha)
        #expect(wardrobe.clothes == [.work: blazer.id, .chill: aloha.id])
        #expect(wardrobe.equipped.isEmpty)
        wardrobe.equip(raincoat)
        #expect(wardrobe.clothes == [.work: raincoat.id, .chill: aloha.id])
        wardrobe.undress(.work)
        #expect(wardrobe.clothes == [.chill: aloha.id])
    }

    @Test func wardrobesKeepTheirClothesAndOldOnesLoad() throws {
        let worn = Wardrobe(equipped: [.gloves: "gloves.gold"], clothes: [.chill: "haku.top.chill.aloha"])
        let data = try JSONEncoder().encode(worn)
        #expect(try JSONDecoder().decode(Wardrobe.self, from: data) == worn)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains(#""chill":"haku.top.chill.aloha""#))
        let old = Data(#"{"equipped":{"gloves":"gloves.gold"}}"#.utf8)
        #expect(try JSONDecoder().decode(Wardrobe.self, from: old) == Wardrobe(equipped: [.gloves: "gloves.gold"]))
        let future = Data(#"{"equipped":{},"clothes":{"dance":"x","work":"haku.top.work.cardigan"}}"#.utf8)
        #expect(try JSONDecoder().decode(Wardrobe.self, from: future).clothes == [.work: "haku.top.work.cardigan"])
    }

    @Test func slotsAndModesFromANewerBuildAreWrittenBack() throws {
        let future = Data(#"{"equipped":{"scarf":"x.scarf","mask":"mask.stripes"},"clothes":{"dance":"x.top"}}"#.utf8)
        var wardrobe = try JSONDecoder().decode(Wardrobe.self, from: future)
        #expect(wardrobe.equipped == [.mask: "mask.stripes"])
        #expect(wardrobe.clothes.isEmpty)
        wardrobe.clear(.mask)
        wardrobe.equip(try item("haku.top.chill.aloha"))
        let saved = try JSONDecoder().decode([String: [String: String]].self, from: JSONEncoder().encode(wardrobe))
        #expect(saved["equipped"] == ["scarf": "x.scarf"])
        #expect(saved["clothes"] == ["dance": "x.top", "chill": "haku.top.chill.aloha"])
    }

    // Prices from the shop catalogue (2026-10-14): tops 30-40, full sets 80-90.
    @Test func clothesFollowTheApprovedPricesAndOnlyHakusAreOnTheShelf() {
        for persona in Persona.allCases {
            let clothes = ShopItem.catalog(for: persona).filter { $0.mode != nil && $0.mode != .boxing }
            #expect(Set(clothes.compactMap(\.mode)) == [.work, .chill, .money], "\(persona)")
            for item in clothes {
                let range = item.slot == .fullSet ? 80...90 : 30...40
                #expect(range.contains(item.price ?? 0), "\(item.id)")
                #expect(item.slot == .top || item.slot == .fullSet)
                #expect(item.isDrawn, "\(item.id)")
            }
            let onShelf = ShopItem.catalog(for: persona, card: .boxing).filter { $0.mode != nil }
            #expect(onShelf.count == clothes.count, "\(persona)")
        }
    }

    // 2026-10-04 is a Sunday.
    func weeklyItem(firstCan: String, now: String, persona: Persona = .haku) throws -> String? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let day = DateFormatter()
        day.calendar = calendar
        day.timeZone = calendar.timeZone
        day.dateFormat = "yyyy-MM-dd HH:mm"
        let store = GrowthStore(fileURL: nil, deviceID: "t")
        store.persona = persona
        store.record(.boxing, source: "first", at: try #require(day.date(from: firstCan)))
        let drawn = ShopItem.catalog.map { item in
            var item = item
            item.isDrawn = item.isDrawn || item.week != nil
            return item
        }
        return ShopItem.weekly(
            for: persona, from: drawn, ledger: store.ledger, now: try #require(day.date(from: now)), calendar: calendar
        )?.id
    }

    @Test func aWeeklyItemShowsFromTheThirdWeekAndTakesTurns() throws {
        #expect(try weeklyItem(firstCan: "2026-10-07 12:00", now: "2026-10-17 23:59") == nil)
        #expect(try weeklyItem(firstCan: "2026-10-07 12:00", now: "2026-10-18 00:00") == "haku.weekly.headband.orange")
        #expect(try weeklyItem(firstCan: "2026-10-07 12:00", now: "2026-10-24 23:59") == "haku.weekly.headband.orange")
        #expect(try weeklyItem(firstCan: "2026-10-07 12:00", now: "2026-10-25 00:00") == "haku.weekly.mask.dots")
        #expect(try weeklyItem(firstCan: "2026-10-04 00:00", now: "2026-11-08 08:00") == "haku.weekly.top.badge")
        #expect(try weeklyItem(firstCan: "2026-10-04 00:00", now: "2026-12-06 08:00") == "haku.weekly.hat.beanie")
        // Eight items, then it starts over.
        #expect(try weeklyItem(firstCan: "2026-10-04 00:00", now: "2026-12-13 08:00") == "haku.weekly.headband.orange")
        // The second character has her own rotation, counted from her own first can.
        #expect(
            try weeklyItem(firstCan: "2026-10-03 23:59", now: "2026-10-18 00:00", persona: .kuro)
                == "kuro.weekly.blanket.bear")
        #expect(
            try weeklyItem(firstCan: "2026-10-04 00:00", now: "2026-11-08 08:00", persona: .kuro)
                == "kuro.weekly.hair.cherry")
    }

    @Test func hakusWeeklyItemsAreDrawn() {
        let weekly = ShopItem.catalog(for: .haku).filter { $0.week != nil }
        #expect(weekly.map(\.week) == Array(1...8))
        // The badge and the beanie wait for their art.
        #expect(weekly.filter { !$0.isDrawn }.map(\.slot) == [.badge, .hat])
        let hers = ShopItem.catalog(for: .kuro).filter { $0.week != nil }
        #expect(hers.map(\.week) == Array(1...8))
        #expect(hers.allSatisfy { $0.isDrawn })
    }

    @Test func noWeeklyItemWithoutCansOrArt() throws {
        #expect(ShopItem.weekly(for: .haku, ledger: CanLedger(), now: at) == nil)
        let store = GrowthStore(fileURL: nil, deviceID: "t")
        store.record(.boxing, source: "old", at: at.addingTimeInterval(-60 * 86_400))
        // Only HAKU has cans here, so only his rotation has started.
        #expect(ShopItem.weekly(for: .haku, ledger: store.ledger, now: at) != nil)
        #expect(ShopItem.weekly(for: .kuro, ledger: store.ledger, now: at) == nil)
    }

    @Test func weeklyItemsStayOffTheRegularShelf() {
        let weekly = ShopItem.catalog.filter { $0.week != nil }
        #expect(weekly.allSatisfy { (15...20).contains($0.price ?? 0) && $0.mode == nil && $0.card == nil })
        for persona in Persona.allCases {
            let weeks = weekly.filter { $0.persona == persona }.compactMap(\.week)
            #expect(weeks == weeks.sorted() && Set(weeks).count == weeks.count, "\(persona)")
            #expect(ShopItem.catalog(for: persona, card: nil).allSatisfy { $0.week == nil })
        }
    }

    @Test func shelvesGroupSlotsByWhereTheyAreWorn() {
        #expect(Slot.allCases.filter { $0.shelf == .clothes } == [.top, .fullSet])
        #expect(Slot.allCases.filter { $0.shelf == .accessories } == [.headband, .mask, .celebration, .badge, .hat])
        #expect(Slot.allCases.filter { $0.shelf == .props } == [.gloves])
        #expect(Slot.allCases.filter { $0.shelf == .room } == [.room])
    }

    @Test func propsShowOnlyInTheIdentityCardsModeWithACard() {
        #expect(WardrobeShelf.shelves(in: .boxing, card: .art) == [.clothes, .accessories, .props, .room])
        #expect(WardrobeShelf.shelves(in: .chill, card: .boxing) == [.clothes, .accessories, .room])
        #expect(WardrobeShelf.shelves(in: .boxing, card: nil) == [.clothes, .accessories, .room])
    }

    @Test func theWardrobeListsItemsForTheModeAndCard() throws {
        let pink = try #require(ShopItem.item("gloves.pink"))
        let mask = try #require(ShopItem.item("mask.stripes"))
        let bag = try #require(ShopItem.item("room.bag"))
        let aloha = try #require(ShopItem.item("haku.top.chill.aloha"))
        #expect(pink.shows(in: .boxing, card: .boxing))
        #expect(!pink.shows(in: .boxing, card: .art))
        #expect(!pink.shows(in: .work, card: .boxing))
        #expect(mask.shows(in: .work, card: .art))
        #expect(mask.shows(in: .boxing, card: nil))
        #expect(bag.shows(in: .chill, card: .boxing))
        #expect(!bag.shows(in: .chill, card: .tennis))
        #expect(aloha.shows(in: .chill, card: nil))
        #expect(!aloha.shows(in: .work, card: nil))
        let racket = try #require(ShopItem.item("kuro.racket.gold"))
        #expect(racket.shows(in: .boxing, card: .tennis))
        #expect(!racket.shows(in: .boxing, card: .boxing))
    }

    @Test func wearingCoversClothesInTheirMode() throws {
        let aloha = try #require(ShopItem.item("haku.top.chill.aloha"))
        let mask = try #require(ShopItem.item("mask.stripes"))
        var wardrobe = Wardrobe()
        wardrobe.equip(aloha)
        wardrobe.equip(mask)
        #expect(wardrobe.isWearing(aloha))
        #expect(wardrobe.isWearing(mask))
        wardrobe.undress(.chill)
        #expect(!wardrobe.isWearing(aloha))
    }

    @Test func wornHasOnlyThatModesClothes() {
        let wardrobe = Wardrobe(
            equipped: [.mask: "mask.stripes"],
            clothes: [.work: "kuro.top.work.blouse", .chill: "kuro.top.chill.cardigan"]
        )
        #expect(wardrobe.worn(in: .work) == ["mask.stripes", "kuro.top.work.blouse"])
        #expect(wardrobe.worn(in: .money) == ["mask.stripes"])
    }

    @Test func aHatIsWornOnlyOffWork() throws {
        let beanie = try item("haku.weekly.hat.beanie")
        let badge = try item("haku.weekly.top.badge")
        #expect(beanie.shows(in: .chill, card: nil))
        #expect(!beanie.shows(in: .work, card: nil))
        #expect(!beanie.shows(in: .boxing, card: .boxing))
        #expect(badge.shows(in: .work, card: nil) && badge.shows(in: .boxing, card: .art))
        var wardrobe = Wardrobe()
        wardrobe.equip(beanie)
        wardrobe.equip(badge)
        #expect(wardrobe.worn(in: .chill) == [beanie.id, badge.id])
        #expect(wardrobe.worn(in: .work) == [badge.id])
    }

    @Test func anotherCardsItemsAreHiddenButKept() {
        let wardrobe = Wardrobe(
            equipped: [.gloves: "gloves.pink", .mask: "mask.stripes", .room: "room.bag", .headband: "headband.future"],
            clothes: [.chill: "haku.top.chill.aloha"]
        )
        #expect(
            wardrobe.showing(card: .art)
                == Wardrobe(
                    equipped: [.mask: "mask.stripes", .headband: "headband.future"],
                    clothes: [.chill: "haku.top.chill.aloha"]
                )
        )
        #expect(wardrobe.showing(card: .boxing) == wardrobe)
    }

    @Test func eachFirstBatchCardHasAPropColourAndAGoldProp() {
        let cards: [Persona: [IdentityKind]] = [
            .haku: [.tennis, .fitness, .study, .art], .kuro: [.boxing, .fitness, .study, .art],
        ]
        for (persona, kinds) in cards {
            for card in kinds {
                let line = ShopItem.catalog(for: persona).filter {
                    $0.card == card && $0.slot == .gloves && !$0.isDrawn
                }
                #expect(line.compactMap(\.price) == [15], "\(persona) \(card)")
                #expect(line.compactMap(\.keepsake).map(\.count) == [10], "\(persona) \(card)")
                #expect(line.allSatisfy { $0.suits(card) && !$0.suits(nil) && $0.slot.shelf == .props })
            }
        }
    }

    @Test func cardsWithoutTheirOwnOutfitShareABaseOutfit() {
        #expect(IdentityKind.boxing.baseOutfit(for: .haku) == nil)
        #expect(IdentityKind.boxing.baseOutfit(for: .kuro) == .sport)
        #expect(IdentityKind.tennis.baseOutfit(for: .haku) == .sport)
        #expect(IdentityKind.tennis.baseOutfit(for: .kuro) == nil)
        for persona in Persona.allCases {
            #expect(IdentityKind.fitness.baseOutfit(for: persona) == .sport)
            #expect(IdentityKind.study.baseOutfit(for: persona) == .outing)
            #expect(IdentityKind.art.baseOutfit(for: persona) == .craft)
        }
    }

    @Test func baseClothesSuitEveryCardOnTheirBase() throws {
        let tank = try item("haku.top.gym.tank")
        #expect(tank.suits(.fitness) && tank.suits(.tennis) && tank.suits(.ski))
        #expect(!tank.suits(.boxing) && !tank.suits(.art) && !tank.suits(nil))
        let apron = try item("haku.top.art.apron")
        #expect(apron.suits(.art) && !apron.suits(.study))
        let track = try item("kuro.top.gym.track")
        #expect(track.suits(.boxing) && !track.suits(.tennis))
        #expect(tank.shows(in: .boxing, card: .fitness))
        #expect(!tank.shows(in: .chill, card: .fitness))
    }

    @Test func cardTopsSuitOnlyTheirCard() throws {
        let jacket = try item("haku.top.boxing.blackgold")
        #expect(jacket.suits(.boxing) && !jacket.suits(.tennis) && !jacket.suits(nil))
        let lilac = try item("kuro.top.boxing.lilac")
        #expect(lilac.suits(.boxing) && !lilac.suits(.fitness))
        #expect(try item("kuro.top.tennis.sakura").suits(.tennis))
    }

    @Test func identityClothesAreWornInTheCardsModeAtTheirPrices() {
        let clothes = ShopItem.catalog.filter { $0.mode == .boxing }
        #expect(clothes.count == 15)
        for item in clothes {
            #expect(item.slot == .top, "\(item.id)")
            #expect((item.card == nil) != (item.base == nil), "\(item.id)")
            #expect(item.price == 30 || item.price == 40, "\(item.id)")
            #expect(!item.isDrawn, "\(item.id)")
        }
        for persona in Persona.allCases {
            for base in BaseOutfit.allCases {
                let prices = clothes.filter { $0.persona == persona && $0.base == base }.compactMap(\.price)
                #expect(prices == [30, 40], "\(persona) \(base)")
            }
        }
    }

    @Test func aKeepsakeWaitsForItsArt() throws {
        let store = GrowthStore(fileURL: nil, deviceID: "t")
        for day in 0..<10 {
            #expect(store.record(.boxing, source: "day-\(day)", at: at, card: .fitness).isEmpty)
        }
        #expect(!store.ledger.only(.haku).owned.contains("haku.dumbbell.gym.gold"))
        #expect(try item("haku.dumbbell.gym.gold").keepsake?.card == .fitness)
    }

    @Test func switchingToACardOnAnotherBaseHidesTheWornBaseTop() {
        let wardrobe = Wardrobe(clothes: [.boxing: "haku.top.gym.tank"])
        #expect(wardrobe.showing(card: .tennis) == wardrobe)
        #expect(wardrobe.showing(card: .art).clothes.isEmpty)
        #expect(wardrobe.clothes[.boxing] == "haku.top.gym.tank")
    }
}
