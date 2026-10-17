import Foundation
import Testing

@testable import HubCore

@Suite struct ShareCardTests {
    let look = Look(mode: .work, wardrobe: Wardrobe(equipped: [.headband: "headband.cyan"]), card: .boxing)

    func card(_ id: String, persona: Persona = .haku) throws -> ShareCard {
        let item = try #require(ShopItem.item(id))
        return try #require(ShareCard(persona: persona, look: look, item: item))
    }

    // 分享卡方案 v1: nothing on a card may tell when or where. A stored property holding a date, a place or a
    // number fails here, so it can't slip in later.
    @Test func aCardHoldsNoDatePlaceOrNumber() throws {
        var found: [String] = []
        func walk(_ value: Any, path: String) {
            switch value {
            case is Date, is HubPlace, is HubPlace.Kind, is Int, is Double, is CGFloat:
                found.append("\(path): \(type(of: value))")
            default:
                for child in Mirror(reflecting: value).children {
                    walk(child.value, path: "\(path).\(child.label ?? "_")")
                }
            }
        }
        walk(try card("gloves.gold"), path: "card")
        walk(try card("gloves.gold").words(counting: "拳击"), path: "words")
        #expect(found.isEmpty, "\(found)")
    }

    @Test func aKeepsakeGetsAKeepsakeCardAndABoughtItemAnOutfitCard() throws {
        #expect(try card("gloves.gold").subject == .keepsake("gloves.gold"))
        #expect(try card("haku.top.chill.aloha").subject == .outfit("haku.top.chill.aloha"))
        #expect(try card("haku.set.work.raincoat").subject == .outfit("haku.set.work.raincoat"))
        let plant = try #require(ShopItem.item("room.plant"))
        #expect(ShareCard(persona: .haku, look: look, item: plant) == nil)
    }

    @Test func aKeepsakeCardCountsOnlyTheCumulativeWins() throws {
        let words = try card("gloves.gold").words(counting: "拳击")
        #expect(words == ShareCard.Words(name: "HAKU", title: "金拳套", subtitle: "第 10 次拳击", line: "……给你的。顺手。"))
    }

    @Test func anOutfitCardSaysItWasPutOnWithoutACount() throws {
        let words = try card("kuro.top.chill.hoodie", persona: .kuro).words(counting: "网球")
        #expect(words == ShareCard.Words(name: "KURO", eyebrow: "换上了", title: "猫耳卫衣", line: "……换好了。"))
    }

    @Test func eachCharacterHasHerOwnLine() throws {
        #expect(try card("gloves.gold").line == "……给你的。顺手。")
        #expect(try card("kuro.top.chill.hoodie", persona: .kuro).line == "……换好了。")
        #expect(ShareCard(persona: .kuro, look: look, subject: .keepsake("x")).line == "……这个，留着。")
        #expect(try card("haku.top.chill.aloha").line == "……别盯着看。")
    }

    @Test func theCardWearsItsItemOverTheLookOfThatDay() throws {
        let worn = try card("haku.top.chill.aloha").wornLook
        #expect(worn.wardrobe.clothes[.chill] == "haku.top.chill.aloha")
        #expect(worn.wardrobe.equipped[.headband] == "headband.cyan")
        #expect(worn.mode == .work)
        #expect(worn.card == .boxing)
    }

    @Test func anItemThisBuildDoesNotKnowKeepsTheLookAndAnEmptyTitle() {
        let card = ShareCard(persona: .haku, look: look, subject: .outfit("future.item"))
        #expect(card.item == nil)
        #expect(card.wornLook == look)
        #expect(card.words(counting: "拳击").title == "")
    }

    @Test func theShapesRenderAtTheSpecSizes() {
        let story = ShareCard.Shape.story.size
        let square = ShareCard.Shape.square.size
        #expect([story.width, story.height] == [360, 640])
        #expect([square.width, square.height] == [360, 360])
    }
}
