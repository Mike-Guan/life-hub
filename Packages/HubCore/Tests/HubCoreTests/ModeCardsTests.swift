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
        #expect(!IdentityKind.swimming.isReleased)
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

    @Test func tryingACharacterPutsTheOwnCardsAsideAndBack() throws {
        let suite = "ModeCardsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        ModeCards.restoreOwn(in: defaults)
        #expect(ModeCards.stored(in: defaults) == nil)
        let own = ModeCards(identity: .art)
        own.store(in: defaults)
        #expect(!ModeCards.isTrying(in: defaults))

        ModeCards.tryDefaults(of: .haku, from: .haku, in: defaults)
        #expect(ModeCards.isTrying(in: defaults))
        #expect(ModeCards.stored(in: defaults) == ModeCards(identity: .boxing))
        ModeCards.switchWhileTrying(to: .kuro, in: defaults)
        #expect(ModeCards.stored(in: defaults) == ModeCards(identity: .tennis))
        ModeCards.tryDefaults(of: .kuro, from: .kuro, in: defaults)
        #expect(ModeCards.stored(in: defaults) == ModeCards(identity: .tennis))

        ModeCards.restoreOwn(in: defaults)
        #expect(!ModeCards.isTrying(in: defaults))
        #expect(ModeCards.stored(in: defaults) == own)
    }

    @Test func switchingBackToTheOwnCharacterRestoresTheOwnCards() throws {
        let suite = "ModeCardsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let own = ModeCards(identity: .art)
        own.store(in: defaults)
        ModeCards.switchWhileTrying(to: .kuro, in: defaults)
        #expect(ModeCards.stored(in: defaults) == own)

        ModeCards.tryDefaults(of: .haku, from: .haku, in: defaults)
        ModeCards.switchWhileTrying(to: .kuro, in: defaults)
        #expect(ModeCards.stored(in: defaults) == ModeCards(identity: .tennis))
        ModeCards.switchWhileTrying(to: .haku, in: defaults)
        #expect(!ModeCards.isTrying(in: defaults))
        #expect(ModeCards.stored(in: defaults) == own)
    }

    @Test func tryingWithNoSavedCardsRestoresTheDefaults() throws {
        let suite = "ModeCardsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        ModeCards.tryDefaults(of: .kuro, from: .kuro, in: defaults)
        ModeCards.restoreOwn(in: defaults)
        #expect(ModeCards.stored(in: defaults) == ModeCards())
    }

    @Test func aPickedCardBringsItsOwnCodeLineAndSymbol() {
        let cards = ModeCards(identity: .swimming)
        #expect(cards.pickedIdentity(for: .boxing, persona: .haku) == .swimming)
        #expect(cards.pickedIdentity(for: .work, persona: .haku) == nil)
        #expect(cards.code(for: .boxing, persona: .haku) == "SWIM")
        #expect(cards.tagline(for: .boxing, persona: .haku) == "泳镜推上去了")
        #expect(ModeCards(identity: .ski).tagline(for: .boxing, persona: .kuro) == "围巾裹好了")
        #expect(cards.code(for: .work, persona: .haku) == "WORK")
        #expect(IdentityKind.swimming.symbol == "figure.pool.swim")
    }

    @Test func eachCardInvitesInTheCharactersVoice() {
        #expect(IdentityKind.tennis.invite(for: .haku) == "球拍在门口。去不去随你。")
        #expect(IdentityKind.tennis.invite(for: .kuro) == "今天网球。……拍子带好了。")
        #expect(IdentityKind.ski.invite(for: .haku) == "雪板靠在门口了。")
        for kind in IdentityKind.allCases {
            #expect(!kind.invite(for: .kuro).isEmpty && !kind.tagline(for: .kuro).isEmpty)
            #expect(!kind.lines(for: .haku).isEmpty && !kind.lines(for: .kuro).isEmpty)
        }
    }

    @Test func theCharactersOwnCardKeepsHerLines() {
        let haku = ModeCards.legacy(for: .haku)
        #expect(haku.pickedIdentity(for: .boxing, persona: .haku) == nil)
        #expect(haku.code(for: .boxing, persona: .haku) == Mode.boxing.code(for: .haku))
        #expect(haku.tagline(for: .boxing, persona: .haku) == Mode.boxing.tagline(for: .haku))
        let kuro = ModeCards.legacy(for: .kuro)
        #expect(kuro.tagline(for: .boxing, persona: .kuro) == Mode.boxing.tagline(for: .kuro))
        #expect(ModeCards(identity: .boxing).pickedIdentity(for: .boxing, persona: .kuro) == .boxing)
    }

    @Test func withoutAnIdentityCardOnlyThreeModesShow() {
        #expect(ModeCards().modes == [.work, .chill, .money])
        #expect(ModeCards(identity: .art).modes == Mode.allCases)
        var unknown = ModeCards()
        unknown.identityName = "surfing"
        #expect(unknown.modes == Mode.allCases)
    }

    @Test func aNewInstallStartsWithTheGenericCards() throws {
        let suite = "ModeCardsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(ModeCards.current(in: defaults, persona: .kuro) == ModeCards())
        ModeCards.adopt(in: defaults, persona: .kuro, existingInstall: false)
        #expect(ModeCards.current(in: defaults, persona: .kuro).identity == nil)
        // Records saved later don't turn a new install into the legacy cards.
        ModeCards.adopt(in: defaults, persona: .kuro, existingInstall: true)
        #expect(ModeCards.current(in: defaults, persona: .kuro) == ModeCards())
    }

    @Test func anInstallWithRecordsKeepsItsCharactersCards() throws {
        let suite = "ModeCardsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        ModeCards.adopt(in: defaults, persona: .kuro, existingInstall: true)
        #expect(ModeCards.current(in: defaults, persona: .kuro) == .legacy(for: .kuro))
        ModeCards(identity: .study).store(in: defaults)
        ModeCards.adopt(in: defaults, persona: .kuro, existingInstall: true)
        #expect(ModeCards.current(in: defaults, persona: .kuro).identity == .study)
    }

    // Issue #350: with no translation in the catalog the Chinese text comes back unchanged.
    @Test func textWithoutATranslationStaysChinese() {
        #expect("拳击日".localized == "拳击日")
        #expect(IdentityKind.dance.tagline(for: .haku) == "歌单选好了")
        #expect(IdentityKind.ski.lines(for: .kuro) == ["……好冷。", "手好冰。", "……再滑一次？"])
        #expect(ChillActivity.walking.title == "散步晒太阳")
    }

    // Issue #416: after the default cards, the identity card can be added, changed or cleared in Settings.
    @Test func identityCardCanBeAddedChangedAndCleared() {
        var cards = ModeCards()
        #expect(cards.identity == nil)
        // #expect can't call a mutating method, so each result is kept first.
        let swimming = cards.pickIdentity(.swimming)
        #expect(!swimming)
        #expect(cards.identity == .swimming)
        #expect(cards.title(for: .boxing, persona: .haku) == IdentityKind.swimming.title)
        let study = cards.pickIdentity(.study)
        #expect(!study)
        #expect(cards.identity == .study)
        let cleared = cards.pickIdentity(nil)
        #expect(!cleared)
        #expect(cards.identity == nil)
        #expect(cards.chill == Set(ChillActivity.allCases))
    }

    @Test func fitnessCardTakesTheGymOutOfChillAndGivesItBack() {
        var cards = ModeCards()
        let fitness = cards.pickIdentity(.fitness)
        #expect(fitness)
        #expect(!cards.chill.contains(.fitness))
        // Picking it again moves nothing.
        let again = cards.pickIdentity(.fitness)
        #expect(!again)
        let boxing = cards.pickIdentity(.boxing)
        #expect(!boxing)
        #expect(cards.chill.contains(.fitness))
        // Leaving the fitness card puts 健身 in Chill even if it wasn't there before: it was on the card.
        var noGym = ModeCards(chill: [.walking])
        let moved = noGym.pickIdentity(.fitness)
        #expect(!moved)
        noGym.pickIdentity(nil)
        #expect(noGym.chill == [.walking, .fitness])
    }
}
