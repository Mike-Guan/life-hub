import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

@Suite struct CardPropColourTests {
    @Test(arguments: Outfit.propColors.keys.sorted())
    func eachColourChangesItsProp(_ id: String) throws {
        let outfit = Outfit(Wardrobe(equipped: [.gloves: id]))
        #expect(!outfit.props.isEmpty)
        #expect(outfit.gloves == nil, "a prop colour leaves the gloves red")
        // The gold bookmark and the neon pick are drawn in their own colours.
        for (part, swaps) in outfit.props {
            let inks = RunnerArt.cachedInks(part)
            let colours = Set(inks.compactMap(\.fill) + inks.compactMap(\.stroke))
            for (from, to) in swaps {
                #expect(colours.contains(from), "\(id): \(part) has no such colour to swap")
                #expect(!colours.contains(to), "\(id): \(part) already has that colour")
            }
        }
    }

    @Test func aBoughtPickAndBookmarkJoinTheirCardsLook() {
        func parts(_ card: IdentityKind, _ id: String?) -> [RunnerPart] {
            var pose = RunnerPose().wearing(Outfit(Wardrobe(equipped: id.map { [.gloves: $0] } ?? [:])))
            pose.cardLook = RunnerCardLook(card: card)
            return RunnerFigure.parts(for: .boxing, pose: pose)
        }
        #expect(!parts(.music, nil).contains(.pickPendant))
        #expect(parts(.music, "haku.pick.music.neon").contains(.pickPendant))
        #expect(!parts(.study, "haku.pick.music.neon").contains(.pickPendant))
        #expect(!parts(.study, nil).contains(.bookmarkRibbon))
        #expect(parts(.study, "haku.bookmark.study.gold").contains(.bookmarkRibbon))
    }

    @Test func aPropIconFramesTheProp() {
        let outfit = Outfit(Wardrobe(equipped: [.gloves: "haku.racket.tennis.mint"]))
        let picture = ItemPicture(slot: .gloves, outfit: outfit, itemID: "haku.racket.tennis.mint")
        #expect(picture.parts == [.tennisRacket])
        #expect(picture.crop.width == picture.crop.height)
        let bounds = RunnerArt.cachedInks(.tennisRacket).reduce(CGRect.null) { $0.union($1.path.boundingRect) }
        #expect(picture.crop.contains(bounds))
        #expect(ItemPicture(slot: .gloves, outfit: Outfit(), itemID: nil).parts == [.gloveR])
    }
}
