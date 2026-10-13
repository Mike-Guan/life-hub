import Foundation
import Testing

@testable import HubCore

@Suite struct ModeCardsTests {
    @Test func existingInstallsKeepTheirCharactersCards() {
        let haku = ModeCards.legacy(for: .haku)
        #expect(haku.identity == .boxing)
        #expect(haku.title(for: .boxing, persona: .haku) == "拳击日")
        #expect(haku.title(for: .work, persona: .haku) == "上班")
        #expect(haku.sideStates == [.vibeCoding, .shooting, .operating])
        #expect(haku.chill == Set(ChillActivity.allCases))
        let kuro = ModeCards.legacy(for: .kuro)
        #expect(kuro.identity == .tennis)
        #expect(kuro.title(for: .chill, persona: .kuro) == "下班")
    }

    @Test func renamingChangesOnlyTheCommonCardsName() {
        var cards = ModeCards(identity: .swimming)
        let renamed = cards.rename(.work, to: " 上学 ")
        #expect(renamed)
        #expect(cards.title(for: .work, persona: .haku) == "上学")
        let tooLong = cards.rename(.work, to: "一二三四五六七")
        #expect(tooLong)
        #expect(cards.title(for: .work, persona: .haku) == "一二三四")
        cards.rename(.work, to: "SchoolDays")
        #expect(cards.title(for: .work, persona: .haku) == "SchoolDa")
        cards.rename(.work, to: "上学 day")
        #expect(cards.title(for: .work, persona: .haku) == "上学 day")
        let identityRenamed = cards.rename(.boxing, to: "水")
        #expect(!identityRenamed)
        #expect(cards.title(for: .boxing, persona: .haku) == "游泳")
        #expect(ModeCards.width(of: "上学 day") == 8)
        let cleared = cards.rename(.work, to: "")
        #expect(cleared)
        #expect(cards.title(for: .work, persona: .haku) == "上班")
    }

    @Test func withoutAnIdentityCardTheSlotShowsTheDefault() {
        let cards = ModeCards()
        #expect(cards.identity == nil)
        #expect(cards.title(for: .boxing, persona: .haku) == "拳击日")
        #expect(cards.card(for: .boxing) == nil)
    }

    @Test func sideStatesCycleInThePickedOrder() {
        var cards = ModeCards()
        #expect(cards.sideStates == [.vibeCoding])
        #expect(cards.next(after: .vibeCoding) == .vibeCoding)
        let pickedNone = cards.pickSideStates([])
        #expect(!pickedNone)
        let picked = cards.pickSideStates([.writing, .writing, .studying, .shooting, .operating])
        #expect(picked)
        #expect(cards.sideStates == [.writing, .studying, .shooting])
        #expect(cards.next(after: .writing) == .studying)
        #expect(cards.next(after: .shooting) == .writing)
        #expect(cards.next(after: .operating) == .writing)
        #expect(ModeCards(sideStates: []).sideStates == [.vibeCoding])
    }

    @Test func newSideStatesKeepTheOldTapCycleAndLooks() {
        #expect(SideHustle.writing.next == .vibeCoding)
        #expect(SideHustle.writing.moment == .vibeCoding)
        #expect(SideHustle.studying.moment == .vibeCoding)
        #expect(SideHustle.studying.title == "学习")
    }

    @Test func workoutsSwitchOnlyToThePickedCard() {
        let cards = ModeCards(identity: .tennis)
        #expect(cards.card(for: .racket) == .tennis)
        #expect(cards.card(for: .boxing) == nil)
        #expect(ModeCards(identity: .ski).card(for: .outdoor) == nil)
        #expect(ModeCards(identity: .outdoor).card(for: .outdoor) == .outdoor)
        #expect(IdentityKind.music.workouts.isEmpty)
    }

    @Test func onlyReleasedKindsAreListed() {
        #expect(IdentityKind.released.allSatisfy { $0.isReleased })
        #expect(IdentityKind.boxing.isReleased)
        #expect(!IdentityKind.ski.isReleased)
        #expect(IdentityKind.allCases.count == 12)
        #expect(IdentityKind.allCases.allSatisfy { ModeCards.width(of: $0.title) <= ModeCards.nameWidth })
        #expect(ChillActivity.allCases.allSatisfy { !$0.title.isEmpty })
    }

    @Test func roundTripsThroughJSON() throws {
        var cards = ModeCards(identity: .yoga, chill: [.running, .shopping], sideStates: [.shooting])
        cards.rename(.money, to: "自己的事")
        let data = try JSONEncoder().encode(cards)
        #expect(try JSONDecoder().decode(ModeCards.self, from: data) == cards)
    }

    @Test func decodingToleratesMissingAndUnknownValues() throws {
        let empty = try JSONDecoder().decode(ModeCards.self, from: Data("{}".utf8))
        #expect(empty == ModeCards())
        let json = #"""
            {"identity":"surfing","chill":["running","knitting"],"sideStates":["future"],"names":{"work":"上学"}}
            """#
        let cards = try JSONDecoder().decode(ModeCards.self, from: Data(json.utf8))
        #expect(cards.identity == nil)
        #expect(cards.identityName == "surfing")
        #expect(cards.chill == [.running])
        #expect(cards.sideStates == [.vibeCoding])
        #expect(cards.title(for: .work, persona: .haku) == "上学")
        let rewritten = try JSONDecoder().decode(ModeCards.self, from: JSONEncoder().encode(cards))
        #expect(rewritten.identityName == "surfing")
        // An older build writes back what only a newer one knows.
        let raw = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(cards)) as? [String: Any]
        )
        #expect(raw["chill"] as? [String] == ["running", "knitting"])
        #expect(raw["sideStates"] as? [String] == ["future"])
    }

    @Test func pickingSideStatesDropsTheOnesThisBuildCantShow() throws {
        let json = #"{"sideStates":["shooting","future"]}"#
        var cards = try JSONDecoder().decode(ModeCards.self, from: Data(json.utf8))
        #expect(cards.sideStates == [.shooting])
        cards.pickSideStates([.operating])
        let raw = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(cards)) as? [String: Any]
        )
        #expect(raw["sideStates"] as? [String] == ["operating"])
    }

    @Test func storesInUserDefaults() throws {
        let suite = "ModeCardsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(ModeCards.stored(in: defaults) == nil)
        let cards = ModeCards(identity: .art)
        cards.store(in: defaults)
        #expect(ModeCards.stored(in: defaults) == cards)
    }
}
