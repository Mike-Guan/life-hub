import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct KuroShopTests {
    @Test func herItemsHaveTheirOwnIds() {
        let ids = KuroItem.allCases.map(\.rawValue)
        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy { $0.hasPrefix("kuro.") })
        #expect(Set(ids) == Set(ShopItem.catalog(for: .kuro).map(\.id)))
        #expect(KuroItem.allCases.filter(\.isKeepsake) == [.spin, .sakura, .goldRacket])
        #expect(KuroItem.items(["kuro.room.flower", "gloves.gold", "nope"]) == [.flower])
    }

    @Test func anItemShowsOnlyInItsLook() {
        var pose = KuroPose(look: .chill, energy: nil)
        pose.items = [.flower, .blanket, .scrunchie]
        let chill = KuroFigure.parts(for: .chill, pose: pose)
        #expect(chill.contains(.itemFlower) && chill.contains(.itemBlanket) && !chill.contains(.itemScrunchie))
        // The blanket sits over her top and under her cup.
        let blanket = chill.firstIndex(of: .itemBlanket) ?? 0
        let cup = chill.firstIndex(of: .chillCup) ?? 0
        #expect((chill.firstIndex(of: .jacketChill) ?? 99) < blanket && blanket < cup)
        let tennis = KuroFigure.parts(for: .tennis, pose: pose)
        #expect(tennis.contains(.itemScrunchie) && !tennis.contains(.itemFlower))
    }

    @Test func keepsakesTakeThePlaceOfWhatTheyReplace() {
        var pose = KuroPose(look: .tennis, energy: nil)
        pose.items = [.sakura, .goldRacket]
        let parts = Set(KuroFigure.parts(for: .tennis, pose: pose))
        #expect(parts.isSuperset(of: [.itemSakura, .itemGoldRacket]))
        #expect(!parts.contains(.tennisHeadband) && !parts.contains(.tennisRacket))
    }

    @Test func actingCalmFlattensHerMouthButKeepsTheBlush() {
        var pose = KuroPose(look: .chill, energy: nil).showing(.low)
        pose.calm = true
        let parts = Set(KuroFigure.parts(for: .chill, pose: pose))
        #expect(parts.isSuperset(of: [.mouthFlat, .eyesLow, .blush]) && !parts.contains(.mouthCat))
    }

    @Test func theBoxOpensBeforeSheComesOut() {
        let shaking = KuroUnbox(.scrunchie, progress: 0.2)
        #expect(shaking.popOut == 0 && !shaking.stars && shaking.spin == 1)
        let out = KuroUnbox(.scrunchie, progress: 0.6)
        #expect(out.popOut == 1 && out.stars)
        #expect(KuroUnbox(.spin, progress: 0.625).spin < 0)
        #expect(KuroUnbox(.spin, progress: 0.9).spin == 1)
    }

    @Test func eachUnboxingOfHerItemsPlaysOnce() {
        let event = CompanionEvent.unlock(id: "e1", item: KuroItem.bag.rawValue)
        #expect(KuroView.newUnbox(event, last: "")?.1 == .bag)
        #expect(KuroView.newUnbox(event, last: "e1") == nil)
        #expect(KuroView.newUnbox(.unlock(id: "e2", item: "gloves.gold"), last: "") == nil)
    }

    @Test func eachWorkoutIsCheeredOnce() {
        let event = CompanionEvent.celebrate(id: "w1", kind: .cycling)
        #expect(KuroView.newCelebration(event, last: "")?.1 == .cycling)
        #expect(KuroView.newCelebration(event, last: "w1") == nil)
        #expect(KuroView.newCelebration(.unlock(id: "e1", item: KuroItem.bag.rawValue), last: "") == nil)
        #expect(KuroBubbleLines.celebration(.cycling) == "嗯。……还行。")
    }

    @Test func sheActsCalmAboutItemsAndShyAboutKeepsakes() {
        #expect(KuroBubbleLines.unlock(KuroItem.bag.rawValue) == "……还行吧。")
        #expect(KuroBubbleLines.unlock(KuroItem.goldRacket.rawValue) == "……给你的。不是特意挑的。")
    }

    @Test func iconsAreSquareCropsOfTheItem() {
        for item in KuroItem.allCases {
            let crop = KuroItemIcon.crop(KuroItemIcon.parts(item))
            #expect(crop.width == crop.height && crop.width < KuroArt.bounds.height)
        }
        #expect(KuroItemIcon.parts(.lamp) == [.itemLamp])
        #expect(KuroItemIcon.parts(.spin).contains(.eyesHappy))
    }
}
