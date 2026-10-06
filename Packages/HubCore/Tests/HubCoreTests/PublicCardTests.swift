import Foundation
import Testing

@testable import HubCore

@Suite struct PublicCardTests {
    let at = Date(timeIntervalSince1970: 1_790_000_000)

    func card(activity: SharedActivity? = .gym) -> PublicCard {
        PublicCard(
            id: "card",
            characterID: "character",
            wardrobe: Wardrobe(equipped: [.gloves: "gloves.gold"]),
            keepsakes: ["celebrate.up", "gloves.gold"],
            mode: .chill,
            face: .okay,
            activity: activity,
            at: at,
            deviceID: "test"
        )
    }

    @Test func roundTripsThroughJSON() throws {
        let data = try HubJSON.encoder().encode(card())
        #expect(try HubJSON.decoder().decode(PublicCard.self, from: data) == card())
    }

    @Test func missingFieldsUseDefaults() throws {
        let json = #"{"id":"a","characterID":"c","mode":"dancing"}"#
        let decoded = try HubJSON.decoder().decode(PublicCard.self, from: Data(json.utf8))
        #expect(decoded.characterID == "c")
        #expect(decoded.mode == nil)
        #expect(decoded.keepsakes.isEmpty)
        #expect(decoded.activity == nil)
        #expect(decoded.schemaVersion == 1)
        let policy = try HubJSON.decoder().decode(SharePolicy.self, from: Data("{}".utf8))
        #expect(policy == SharePolicy())
    }

    // Adding a field to the card must be a deliberate change to this list.
    @Test func holdsOnlyWhitelistedFields() throws {
        let whitelist: Set<String> = [
            "schemaVersion", "id", "characterID", "wardrobe", "keepsakes", "mode", "face", "activity",
            "createdAt", "updatedAt", "updatedBy", "deletedAt",
        ]
        let labels = Set(Mirror(reflecting: card()).children.compactMap(\.label))
        #expect(labels == whitelist)
        let data = try HubJSON.encoder().encode(card())
        let keys = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any]).keys
        #expect(Set(keys).isSubset(of: whitelist))
    }

    // A nil Optional boxed in Any matches every `is T?` check, so compare the exact types instead.
    @Test func cannotHoldPlacesTimesDurationsSleepOrScreenTime() {
        let recordDates: Set<String> = ["createdAt", "updatedAt", "deletedAt"]
        let forbidden: [Any.Type] = [
            Double.self, Double?.self, TimeInterval.self, HubPlace.self, HubPlace?.self, PlacePresence.self,
            PlacePresence?.self, [EnergyEvent].self, EnergyEvent?.self, NeedSignals.self, NeedSignals?.self,
        ]
        for child in Mirror(reflecting: card()).children {
            let label = child.label ?? ""
            let kind = type(of: child.value)
            if kind == Date.self || kind == Date?.self { #expect(recordDates.contains(label), "\(label)") }
            if kind == Int.self || kind == Int?.self { #expect(label == "schemaVersion") }
            #expect(!forbidden.contains { $0 == kind }, "\(label)")
        }
    }

    @Test func tierOneDropsTheActivity() {
        #expect(card().shared(with: SharePolicy()).activity == nil)
        #expect(card().shared(with: SharePolicy()).mode == .chill)
    }

    @Test func tierTwoKeepsTheActivityUnlessHidden() {
        let open = SharePolicy(tier: .activity)
        let hidden = SharePolicy(tier: .activity, hidden: [.walking])
        #expect(card().shared(with: open).activity == .gym)
        #expect(card().shared(with: hidden).activity == .gym)
        #expect(card(activity: .walking).shared(with: hidden).activity == nil)
        #expect(card(activity: nil).shared(with: open).activity == nil)
    }

    @Test func eachRelationshipHasItsOwnPolicy() {
        let settings = ShareSettings(policies: ["partner": SharePolicy(tier: .activity)])
        #expect(settings.policy(for: "partner").tier == .activity)
        #expect(settings.policy(for: "parent") == SharePolicy())
    }

    @Test func readsBackWhatItWrote() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "public-card-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(PublicCard.read(from: url) == nil)
        #expect(PublicCard.read(from: nil) == nil)
        try card().write(to: url)
        #expect(PublicCard.read(from: url) == card())
    }

    @Test func characterIDIsCreatedOnce() throws {
        let suite = "PublicCardTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = HubCharacter.id(defaults: defaults)
        #expect(HubCharacter.id(defaults: defaults) == first)
        #expect(UUID(uuidString: first) != nil)
    }

    @Test func keepsakesAreSorted() {
        #expect(card().keepsakes == ["celebrate.up", "gloves.gold"])
        let other = PublicCard(characterID: "c", keepsakes: ["b", "a"], deviceID: "test")
        #expect(other.keepsakes == ["a", "b"])
    }
}
