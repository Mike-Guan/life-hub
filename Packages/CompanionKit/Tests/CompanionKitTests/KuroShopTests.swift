import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct KuroShopTests {
    @Test func herItemsHaveTheirOwnIds() {
        let ids = KuroItem.allCases.map(\.rawValue)
        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy { $0.hasPrefix("kuro.") })
        // Clothes are drawn before the shop offers them, so every offered item is drawn but not the other way.
        let catalog = ShopItem.catalog(for: .kuro)
        #expect(Set(ids).isSubset(of: catalog.map(\.id)))
        #expect(Set(catalog.filter(\.isDrawn).map(\.id)).isSubset(of: ids))
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

    @Test func sundayHairPiecesGoOnHerPonytailElseOnTheSideClip() {
        var pose = KuroPose(look: .chill, energy: nil)
        pose.items = [.mintTie]
        #expect(KuroFigure.parts(for: .tennis, pose: pose).contains(.weeklyHairMintPony))
        #expect(KuroFigure.parts(for: .box, pose: pose).contains(.weeklyHairMintPony))
        for look in [KuroLook.chill, .work, .desk, .study] {
            let parts = KuroFigure.parts(for: look, pose: pose)
            #expect(parts.contains(.weeklyHairMintSide) && !parts.contains(.weeklyHairMintPony), "\(look)")
        }
        // Static on her: each piece moves with the hair it is worn on.
        pose.idle = .ponytail
        pose.idleProgress = 0.1
        let ponytail = KuroFigure.offset(.tennisPonytail, pose: pose)
        #expect(ponytail != .zero && KuroFigure.offset(.weeklyHairStarPony, pose: pose) == ponytail)
        #expect(KuroFigure.offset(.itemScrunchie, pose: pose) == ponytail)
        #expect(KuroFigure.offset(.weeklyHairStarSide, pose: pose) == KuroFigure.offset(.hairFringe, pose: pose))
    }

    @Test func oneThingOnHerLapAndOneOnTheFloor() {
        var pose = KuroPose(look: .chill, energy: nil)
        pose.items = [.flower, .blanket, .cloud, .succulent]
        let chill = Set(KuroFigure.parts(for: .chill, pose: pose))
        #expect(chill.isSuperset(of: [.weeklyRoomCloud, .weeklyRoomSucculent]))
        #expect(chill.isDisjoint(with: [.itemBlanket, .itemFlower]))
        pose.items = [.bag, .succulent]
        let tennis = Set(KuroFigure.parts(for: .tennis, pose: pose))
        #expect(tennis.contains(.weeklyRoomSucculent) && !tennis.contains(.itemBag))
        pose.items = [.bearBlanket]
        #expect(KuroFigure.parts(for: .chill, pose: pose).contains(.weeklyBlanketBear))
        #expect(!KuroFigure.parts(for: .work, pose: pose).contains(.weeklyBlanketBear))
    }

    @Test func theNightlightHangsOverHerSofaAndHerDesk() {
        var pose = KuroPose(look: .chill, energy: nil)
        pose.items = [.nightlight]
        for look in KuroLook.allCases {
            let parts = Set(KuroFigure.parts(for: look, pose: pose))
            let shown = look == .chill || look == .desk
            #expect(parts.isSuperset(of: [.weeklyRoomNightlightGlow, .weeklyRoomNightlight]) == shown, "\(look)")
        }
        // The glow breathes from 0.2 to 0.65 and back every 3 s, and rests at 0.4.
        #expect(abs(KuroPose.glow(at: 0) - 0.2) < 0.001 && abs(KuroPose.glow(at: 1.5) - 0.65) < 0.001)
        #expect(abs(KuroPose.glow(at: 3) - 0.2) < 0.001 && KuroPose.restingGlow == 0.4)
        #expect(KuroFigure.opacity(.weeklyRoomNightlightGlow, pose: pose) == KuroPose.restingGlow)
        #expect(KuroFigure.opacity(.weeklyRoomNightlightGlow, pose: pose.glowing(0.6)) == 0.6)
        #expect(KuroItemIcon.parts(.nightlight) == [.weeklyRoomNightlightGlow, .weeklyRoomNightlight])
    }

    @Test func herLapIsClearWhileSheDrinks() {
        for item in [KuroItem.blanket, .bearBlanket, .cloud] {
            var pose = KuroPose(look: .chill, energy: nil)
            pose.items = [item]
            pose.tap = .sip
            pose.tapProgress = 0.4
            #expect(Set(KuroFigure.parts(for: .chill, pose: pose)).isDisjoint(with: KuroFigure.lap), "\(item)")
            pose.tap = nil
            pose.idle = .blow
            #expect(Set(KuroFigure.parts(for: .chill, pose: pose)).isDisjoint(with: KuroFigure.lap), "\(item)")
        }
    }

    @Test func theWatchLeavesOutWhatIsOnHerLapOrTheFloor() {
        var pose = KuroPose(look: .chill, energy: nil)
        pose.items = [.bearBlanket, .succulent, .starTie, .nightlight]
        let watch = Set(KuroFigure.parts(for: .chill, pose: pose, watch: true))
        #expect(watch.isDisjoint(with: [.weeklyBlanketBear, .weeklyRoomSucculent]))
        #expect(watch.isSuperset(of: [.weeklyHairStarSide, .weeklyRoomNightlight]))
        pose.items = [.cloud]
        #expect(!KuroFigure.parts(for: .chill, pose: pose, watch: true).contains(.weeklyRoomCloud))
    }

    static let clothes = KuroItem.allCases.filter { $0.clothes != nil }

    @Test func herClothesAreTheCatalogsTopsAndSets() {
        let catalog = ShopItem.catalog(for: .kuro).filter { $0.mode != nil && $0.mode != .boxing }
        #expect(Set(Self.clothes.map(\.rawValue)) == Set(catalog.map(\.id)))
        for item in Self.clothes {
            #expect(item.look.mode == ShopItem.item(item.rawValue)?.mode, "\(item)")
        }
    }

    @Test(arguments: clothes)
    func clothesTakeThePlaceOfHerTopOnlyInTheirLook(_ item: KuroItem) throws {
        let clothes = try #require(item.clothes)
        var pose = KuroPose(look: item.look, energy: nil)
        pose.items = [item]
        let parts = Set(KuroFigure.parts(for: item.look, pose: pose))
        #expect(parts.contains(clothes.top) && !parts.contains(KuroFigure.jacket(item.look)))
        if let hat = clothes.hat { #expect(parts.contains(hat)) }
        let other: KuroLook = item.look == .chill ? .work : .chill
        pose = KuroPose(look: other, energy: nil)
        pose.items = [item]
        #expect(!KuroFigure.parts(for: other, pose: pose).contains(clothes.top))
    }

    @Test(arguments: clothes)
    func herSleevesMatchHerClothes(_ item: KuroItem) throws {
        let clothes = try #require(item.clothes)
        var rub = KuroPose(look: item.look, energy: nil)
        rub.items = [item]
        rub.tap = .rub
        rub.tapProgress = 0.3
        let rubbing = Set(KuroFigure.parts(for: item.look, pose: rub))
        #expect(rubbing.contains(clothes.rubSleeve) && rubbing.contains(.tapRub))
        var invite = KuroPose(look: item.look, energy: nil)
        invite.items = [item]
        invite.scene = .invite(time: 1)
        let pointing = Set(KuroFigure.parts(for: item.look, pose: invite))
        #expect(pointing.contains(clothes.inviteSleeve) && !pointing.contains(KuroScene.sleeve(item.look)))
    }

    @Test func setHatsSitWithHerCatEars() {
        var pose = KuroPose(look: .chill, energy: nil)
        pose.items = [.picnic, .blanket]
        let picnic = KuroFigure.parts(for: .chill, pose: pose)
        #expect(picnic.contains(.setPicnicHat) && picnic.contains(.catEars))
        // Her blanket still covers the top.
        #expect((picnic.firstIndex(of: .setPicnicTop) ?? 99) < (picnic.firstIndex(of: .itemBlanket) ?? 0))
        pose = KuroPose(look: .work, energy: nil)
        pose.items = [.rain]
        let rain = Set(KuroFigure.parts(for: .work, pose: pose))
        #expect(rain.contains(.setRainHat) && !rain.contains(.catEars))
        pose.scene = .dried(time: 1)
        let dried = Set(KuroFigure.parts(for: .work, pose: pose))
        #expect(dried.contains(.bathTurban) && !dried.contains(.setRainHat) && dried.contains(.setRainTop))
    }

    @Test(arguments: clothes)
    func fromBehindSheShowsHerClothesPlainBack(_ item: KuroItem) throws {
        let clothes = try #require(item.clothes)
        var pose = KuroPose(look: item.look, energy: nil)
        pose.items = [item]
        pose.tap = .turnAway
        pose.tapProgress = 0.5
        let back = Set(KuroFigure.parts(for: item.look, pose: pose))
        #expect(back.isSuperset(of: [clothes.back, .backHead]))
        #expect(!back.contains(clothes.top) && !back.contains(KuroFigure.jacket(item.look)))
        if let hat = clothes.hat { #expect(back.contains(hat)) }
    }

    @Test func herThoughtBubbleMovesAboveASetHat() {
        #expect(KuroFigure.offset(.tapDots, pose: KuroPose(look: .work, energy: nil)) == .zero)
        #expect(KuroFigure.offset(.tapDots, pose: KuroPose(look: .work, energy: nil), hatted: true).height < 0)
        #expect(KuroFigure.offset(.backHead, pose: KuroPose(look: .work, energy: nil), hatted: true) == .zero)
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
        #expect(KuroBubbleLines.unlock(KuroItem.goldRacket.rawValue) == "……给你。有点不好意思。")
    }

    @Test func iconsAreSquareCropsOfTheItem() {
        for item in KuroItem.allCases {
            let crop = KuroItemIcon.crop(KuroItemIcon.parts(item))
            #expect(crop.width == crop.height && crop.width < KuroArt.bounds.height)
        }
        #expect(KuroItemIcon.parts(.lamp) == [.itemLamp])
        #expect(KuroItemIcon.parts(.picnic) == [.setPicnicTop, .setPicnicHat])
        #expect(KuroItemIcon.parts(.spin).contains(.eyesHappy))
    }
}
