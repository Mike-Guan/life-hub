import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct KuroTapTests {
    @Test func eachLookHasItsOwnMoveAndSleepyMeansRubbing() {
        let moves = KuroLook.allCases.map { KuroTap(look: $0, sleepy: false) }
        #expect(moves == [.tablet, .sip, .bounce, .glasses])
        #expect(KuroLook.allCases.allSatisfy { KuroTap(look: $0, sleepy: true) == .rub })
    }

    @Test func aMoveIsNeverJustABubble() {
        // Every move changes what is drawn compared with her resting pose.
        for look in KuroLook.allCases {
            let rest = KuroPose(look: look, energy: nil)
            let kind = KuroTap(look: look, sleepy: false)
            let still = KuroFigure.parts(for: look, pose: rest)
            let moved = KuroFigure.parts(for: look, pose: rest.reacting(kind, progress: 0.3))
            #expect(still != moved)
        }
    }

    @Test func theTabletComesUpOverHerFaceThenLowers() {
        let pose = KuroPose(look: .work, energy: nil)
        let up = pose.reacting(.tablet, progress: 0.3)
        let parts = KuroFigure.parts(for: .work, pose: up)
        #expect(parts.contains(.tapTablet) && !parts.contains(.workTablet) && parts.contains(.eyesBright))
        // UI 审核 2026-10-08: her own eyes, and the stylus stays on the desk.
        #expect(!parts.contains(.eyesSurprised) && parts.contains(.workStylus))
        // Drawn after her mask, so it covers it.
        #expect((parts.firstIndex(of: .maskWork) ?? 99) < (parts.firstIndex(of: .tapTablet) ?? 0))
        #expect(KuroFigure.shift(.tapTablet, pose: up).height == 0)
        #expect(KuroFigure.shift(.tapTablet, pose: pose.reacting(.tablet, progress: 0.9)).height > 0)
    }

    @Test func theBallBouncesTwiceAndLands() {
        let pose = KuroPose(look: .tennis, energy: nil)
        let heights = [0.2, 0.4, 0.6, 0.9].map {
            KuroFigure.shift(.tapBall, pose: pose.reacting(.bounce, progress: $0))
        }
        #expect(heights[0].height < -30 && heights[1].height > -1 && heights[2].height < -30)
        #expect(heights[3] == .zero)
        #expect(KuroFigure.parts(for: .tennis, pose: pose.reacting(.bounce, progress: 0.9)).contains(.tapSparkle))
    }

    @Test func sheSipsThenPutsTheCupDown() {
        let pose = KuroPose(look: .chill, energy: nil)
        let sip = Set(KuroFigure.parts(for: .chill, pose: pose.reacting(.sip, progress: 0.4)))
        #expect(sip.isSuperset(of: [.tapCup, .tapPuff, .eyesClosed, .mouthO]) && !sip.contains(.chillCup))
        let after = Set(KuroFigure.parts(for: .chill, pose: pose.reacting(.sip, progress: 0.9)))
        #expect(after.isSuperset(of: [.chillCup, .eyesHappy]) && !after.contains(.tapCup))
        // The cup travels: it starts at the table, is at her lips while she blows, then goes back down.
        let travel = [0.0, 0.1, 0.3, 0.65].map { KuroFigure.shift(.tapCup, pose: pose.reacting(.sip, progress: $0)) }
        #expect(travel[0] == CGSize(width: 26, height: 36) && travel[2] == .zero)
        #expect(travel[1].height > 0 && travel[1].height < 36 && travel[3].height > 0)
        #expect(!KuroFigure.parts(for: .chill, pose: pose.reacting(.sip, progress: 0.1)).contains(.tapPuff))
    }

    // UI 审核 2026-10-08: the rubbing hand floated, and in the chill look a second hand held the cup on that side.
    @Test(arguments: KuroLook.allCases)
    func herRubbingHandComesUpOnHerSleeve(_ look: KuroLook) {
        let rubbing = KuroPose(look: look, energy: 10).reacting(.rub, progress: 0.3)
        let parts = Set(KuroFigure.parts(for: look, pose: rubbing))
        let sleeves: Set<KuroPart> = [.tapRubSleeveWork, .tapRubSleeveChill, .tapRubSleeveTennis, .tapRubSleeveDesk]
        #expect(parts.contains(.tapRub) && parts.intersection(sleeves).count == 1)
        let rest = Set(KuroFigure.parts(for: look, pose: KuroPose(look: look, energy: 10)))
        #expect(rest.isDisjoint(with: sleeves))
    }

    @Test func sheTurnsHerBackWithADotsBubble() {
        let pose = KuroPose(look: .tennis, energy: nil).reacting(.turnAway, progress: 0.5, heart: true)
        let parts = Set(KuroFigure.parts(for: .tennis, pose: pose))
        #expect(parts.isSuperset(of: [.backHead, .tapDots, .tennisPonytail, .catEars]))
        #expect(parts.isDisjoint(with: [.faceBase, .eyesOpen, .eyesBright, .mouthSmile, .tennisRacket, .tapHeart]))
        #expect(KuroTap.turnAway.duration > KuroTap.bounce.duration)
        #expect(KuroView.hop((.turnAway, 0.1)) == 0 && KuroView.hop((.sip, 0.1)) < 0 && KuroView.hop(nil) == 0)
    }

    @Test func theHeartShowsAboutOneTapInFour() {
        #expect(KuroTap.heart(0) && !KuroTap.heart(1) && !KuroTap.heart(3))
        let pose = KuroPose(look: .desk, energy: nil).reacting(.glasses, progress: 0.6, heart: true)
        let parts = Set(KuroFigure.parts(for: .desk, pose: pose))
        #expect(parts.isSuperset(of: [.tapHeart, .tapGlint, .mouthFlat]))
        #expect(KuroFigure.shift(.deskGlasses, pose: pose).height < 0)
    }
}
