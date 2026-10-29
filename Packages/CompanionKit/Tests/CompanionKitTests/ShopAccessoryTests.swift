import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// 商店扩充 v1 §3: HAKU's two headbands with a print and the smiley mask.
@Suite struct ShopAccessoryTests {
    @Test func aPrintedHeadbandDrawsItsPrintOverTheBand() {
        for (id, print) in [("haku.headband.check", RunnerPart.headbandCheck), ("haku.headband.flame", .headbandFlame)]
        {
            let outfit = Outfit(Wardrobe(equipped: [.headband: id]))
            #expect(outfit.headbandPrint == print && outfit.headband != nil, "\(id)")
            let parts = RunnerFigure.parts(for: .boxing, pose: RunnerPose().wearing(outfit))
            let band = parts.firstIndex(of: .headband)
            #expect(band != nil && parts.firstIndex(of: print).map { $0 > band ?? .max } == true, "\(id)")
            #expect(ItemPicture(slot: .headband, outfit: outfit, itemID: id).parts == [.headband, print])
        }
        #expect(!RunnerFigure.parts(for: .boxing, pose: RunnerPose()).contains(.headbandCheck))
    }

    @Test func theSmileyMaskShowsUpAndDown() {
        let outfit = Outfit(Wardrobe(equipped: [.mask: "haku.mask.smile"]))
        #expect(outfit.mask == .smile)
        #expect(RunnerFigure.parts(for: .work, pose: RunnerPose().wearing(outfit)).contains(.maskSmile))
        #expect(RunnerFigure.parts(for: .chill, pose: RunnerPose().wearing(outfit)).contains(.maskSmileDown))
    }
}
