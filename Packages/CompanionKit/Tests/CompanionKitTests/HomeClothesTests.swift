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
