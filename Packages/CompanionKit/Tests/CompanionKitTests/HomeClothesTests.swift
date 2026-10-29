#if os(iOS) || os(macOS)
import HubCore
import Testing

@testable import CompanionKit

@MainActor
@Suite struct HomeClothesTests {
    @Test func everyDrawnTopHasARoomVersionWithTheCompanionsParts() throws {
        let drawn = Set(HomeOutfit.allCases.compactMap(\.shopID))
        #expect(drawn == Set(Outfit.clothesParts.keys))
        for outfit in HomeOutfit.allCases {
            guard let id = outfit.shopID else { continue }
            let parts = try #require(Outfit.clothesParts[id])
            #expect(Set(outfit.parts).union(outfit.hat.map { [$0] } ?? []) == parts, "\(outfit)")
            #expect(outfit.base == Outfit.clothesBackColors[id], "\(outfit)")
        }
        #expect(HomeOutfit(worn: ["haku.top.side.arcade"]) == .arcade)
        #expect(HomeOutfit(worn: ["haku.set.work.raincoat"]).parts.contains(.setKawaiiHood))
    }

    @Test func eachModeAndCardHasItsDefaultLookUntilATopIsBought() {
        #expect(HomeOutfit(worn: [], mode: .work) == .workJacket)
        #expect(HomeOutfit(worn: [], mode: .chill) == .jacket)
        #expect(HomeOutfit(worn: []) == .jacket)
        #expect(HomeOutfit(worn: [], mode: .money).parts.contains(.chainGold))
        #expect(HomeOutfit(worn: [], mode: .money).base == RunnerPalette.jacketMoney)
        #expect(HomeOutfit(worn: [], mode: .boxing, card: .boxing).hat == .headband)
        #expect(HomeOutfit(worn: [], mode: .boxing, card: .tennis).hat == .tennisVisor)
        #expect(HomeOutfit(worn: [], mode: .boxing, card: .ski).hat == .skiGoggles)
        #expect(HomeOutfit(worn: [], mode: .boxing, card: .art).parts.contains(.apron))
        #expect(HomeOutfit(worn: [], mode: .boxing, card: .study) == .jacket)
        // As in the companion, the sport base swaps the neon stripe for the orange one, and cards without a look
        // keep the boxing kit.
        for card in [IdentityKind.tennis, .fitness, .dance, .ski] {
            let parts = HomeOutfit(worn: [], mode: .boxing, card: card).parts
            #expect(parts.contains(.stripeSport) && !parts.contains(.stripeNeon), "\(card)")
            #expect(HomeOutfit(worn: [], mode: .boxing, card: card).base == RunnerCardLook(card: card)?.jacket)
        }
        #expect(HomeOutfit(worn: [], mode: .boxing, card: .yoga) == .boxing)
        #expect(HomeOutfit(worn: ["haku.top.work.blazer"], mode: .work) == .blazer)
        #expect(HomeModel(night: false, mode: .money).outfit == .moneyJacket)
        #expect(HomeModel(night: false).ownedOutfits == [.jacket])
    }

    @Test func theCardHatsStayOffTheBackOfTheHead() {
        #expect(!HakuNode.headParts(.back, hat: .tennisVisor, mask: nil).contains(.tennisVisor))
        #expect(HakuNode.headParts(.back, hat: .headband, mask: nil).contains(.headband))
        #expect(HakuNode.headParts(.box, hat: .tennisVisor, mask: nil).contains(.headband))
        #expect(!HakuNode.headParts(.box, hat: .tennisVisor, mask: nil).contains(.tennisVisor))
    }

    @Test func theHeadWearsTheCapAndTheMaskPrintAsInTheCompanion() {
        let idle = HakuNode.headParts(.idle, hat: .setVarsityCap, mask: .stripes)
        #expect(idle.contains(.setVarsityCap) && idle.contains(.maskStripesDown))
        // The boxing headband takes the cap's place.
        let box = HakuNode.headParts(.box, hat: .setVarsityCap, mask: nil)
        #expect(box.contains(.headband) && !box.contains(.setVarsityCap))
        #expect(HakuNode.headParts(.back, hat: nil, mask: .stripes) == HakuFace.back.parts)
    }

    @Test func accessoriesFollowTheWardrobeAndTheMode() {
        let model = HomeModel(night: false)
        var next = model.snapshot
        next.wardrobe.equipped = [.headband: "headband.cyan", .mask: "mask.stripes", .gloves: "gloves.pink"]
        model.apply(next)
        #expect(model.accessories.headband == RunnerPalette.neonCyan)
        #expect(model.accessories.mask == .stripes)
        #expect(model.accessories.gloves == RunnerPalette.neonPink)
        #expect(HomeModel(night: false).accessories == Outfit())
    }
}
#endif
