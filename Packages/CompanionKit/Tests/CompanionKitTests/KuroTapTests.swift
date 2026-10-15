import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct KuroTapTests {
    @Test func eachLookHasItsOwnMoveAndSleepyMeansRubbing() {
        let moves = KuroLook.allCases.map { KuroTap(look: $0, sleepy: false) }
        #expect(moves == [.tablet, .sip, .swing, .glasses, .bump, .hug, .mark, .sketch, .hug, .hug, .hug])
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

    @Test func sheSwingsTheRacketAcrossHerBodyAndBack() {
        let pose = KuroPose(look: .tennis, energy: nil)
        let angles = [0.05, 0.2, 0.4, 0.6, 0.95].map {
            KuroFigure.turn(.tennisRacket, pose: pose.reacting(.swing, progress: $0))?.angle ?? 99
        }
        #expect(angles[0] == 0 && angles[1] > 0 && angles[2] == -75 && angles[3] > -75 && angles[3] < -50)
        #expect(abs(angles[4]) < 0.001)
        #expect(pose.reacting(.swing, progress: 0.05).eyes == .surprised)
        let swinging = KuroFigure.parts(for: .tennis, pose: pose.reacting(.swing, progress: 0.4))
        #expect(swinging.contains(.swingLines) && swinging.contains(.eyesClosed))
        #expect(!KuroFigure.parts(for: .tennis, pose: pose.reacting(.swing, progress: 0.6)).contains(.swingLines))
        #expect(KuroFigure.turn(.tennisRacket, pose: pose) == nil)
    }

    @Test func theBallBouncesThreeTimesOnTheFlatRacketAndIsCaught() {
        let pose = KuroPose(look: .tennis, energy: nil)
        let juggling = Set(KuroFigure.parts(for: .tennis, pose: pose.idling((.juggle, 0.25))))
        #expect(juggling.isSuperset(of: [.juggleRacket, .tapBall, .eyesBright]) && !juggling.contains(.tennisRacket))
        let heights = [0.25, 0.45, 0.575, 0.79].map { KuroIdle.ballHeight($0) }
        #expect(heights[0] > heights[2] && heights[2] > heights[3] && heights[3] > 0 && heights[1] < 0.001)
        let caught = Set(KuroFigure.parts(for: .tennis, pose: pose.idling((.juggle, 0.95))))
        #expect(caught.isSuperset(of: [.tapSparkle, .eyesHappy]) && KuroIdle.ballHeight(0.95) == 0)
    }

    @Test func theRacketSpinsOneTurnInHerHand() {
        let pose = KuroPose(look: .tennis, energy: nil)
        let widths = [0.0, 0.175, 0.35, 0.7].map {
            KuroFigure.turn(.tennisRacket, pose: pose.idling((.twirl, $0)))?.scale ?? 0
        }
        #expect(widths[0] == 1 && abs(widths[1]) == 0.1 && widths[2] < -0.9 && abs(widths[3] - 1) < 0.001)
        #expect(KuroFigure.parts(for: .tennis, pose: pose.idling((.twirl, 0.9))).contains(.eyesHappy))
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
        let sleeves: Set<KuroPart> = [
            .tapRubSleeveWork, .tapRubSleeveChill, .tapRubSleeveTennis, .tapRubSleeveDesk, .tapRubSleeveBox,
            .tapRubSleeveSmock,
        ]
        #expect(parts.contains(.tapRub) && parts.intersection(sleeves).count == 1)
        // In gloves the rubbing hand is bare: the left glove comes off.
        #expect(!parts.contains(.boxGloveL))
        let rest = Set(KuroFigure.parts(for: look, pose: KuroPose(look: look, energy: 10)))
        #expect(rest.isDisjoint(with: sleeves))
    }

    @Test func sheTurnsHerBackWithADotsBubble() {
        let pose = KuroPose(look: .tennis, energy: nil).reacting(.turnAway, progress: 0.5, heart: true)
        let parts = Set(KuroFigure.parts(for: .tennis, pose: pose))
        #expect(parts.isSuperset(of: [.backHead, .tapDots, .tennisPonytail, .catEars]))
        #expect(parts.isDisjoint(with: [.faceBase, .eyesOpen, .eyesBright, .mouthSmile, .tennisRacket, .tapHeart]))
        #expect(KuroTap.turnAway.duration > KuroTap.swing.duration)
        #expect(KuroView.hop((.turnAway, 0.1)) == 0 && KuroView.hop((.sip, 0.1)) < 0 && KuroView.hop(nil) == 0)
    }

    @Test func theHeartShowsAboutOneTapInFour() {
        #expect(KuroTap.heart(0) && !KuroTap.heart(1) && !KuroTap.heart(3))
        let pose = KuroPose(look: .desk, energy: nil).reacting(.glasses, progress: 0.6, heart: true)
        let parts = Set(KuroFigure.parts(for: .desk, pose: pose))
        #expect(parts.isSuperset(of: [.tapHeart, .tapGlint, .mouthFlat]))
        #expect(KuroFigure.shift(.deskGlasses, pose: pose).height < 0)
    }

    @Test func aTapBringsBackWhatAnIdlePutDownInsteadOfJumping() {
        // 动作展示总表 C9: the pen she put down for the tuck comes back up over the tap's first 0.2 s.
        let tap = KuroPose(look: .art, energy: nil).reacting(.sketch, progress: 0.01)
        let down = tap.cutting((.tuck, 0.5), back: 0)
        #expect(KuroFigure.parts(for: .art, pose: down).contains(.craftPen))
        #expect(KuroFigure.shift(.craftPen, pose: down).height > 40)
        let halfway = KuroFigure.shift(.craftPen, pose: tap.cutting((.tuck, 0.5), back: 0.5)).height
        #expect(halfway > 1 && halfway < 40)
        #expect(abs(KuroFigure.shift(.craftPen, pose: tap.cutting((.tuck, 0.5), back: 1)).height) < 1)
        #expect(KuroTap.cutBack == 0.2)
    }

    @Test func notesCutShortFadeAndTheTapKeepsHerFace() {
        let tap = KuroPose(look: .dance, energy: nil).reacting(.hug, progress: 0.01)
        let parts = Set(KuroFigure.parts(for: .dance, pose: tap.cutting((.groove, 0.2), back: 0.5)))
        #expect(parts.contains(.speakerNoteA) && parts.contains(.eyesClosed) && !parts.contains(.eyesHappy))
        let shown = KuroIdle.groove.opacity(.speakerNoteA, progress: 0.2)
        let fading = KuroFigure.opacity(.speakerNoteA, pose: tap.cutting((.groove, 0.2), back: 0.5))
        #expect(fading > 0 && fading < shown)
        #expect(KuroFigure.opacity(.speakerNoteA, pose: tap.cutting((.groove, 0.2), back: 1)) == 0)
    }

    @Test func aCupAtHerLipsStaysThereForTheSip() {
        let tap = KuroPose(look: .chill, energy: nil).reacting(.sip, progress: 0.01)
        #expect(KuroFigure.shift(.tapCup, pose: tap.cutting((.blow, 0.5), back: 0.5)) == .zero)
        #expect(KuroFigure.shift(.tapCup, pose: tap).height > 30)
    }

    @Test func aTwirlCutShortTurnsBackToTheFront() {
        let tap = KuroPose(look: .tennis, energy: nil).reacting(.swing, progress: 0.05)
        let scale = { KuroFigure.turn(.tennisRacket, pose: tap.cutting((.twirl, 0.35), back: $0))?.scale ?? 0 }
        #expect(scale(0) < -0.9 && abs(scale(1) - 1) < 0.001)
        #expect(KuroFigure.turn(.tennisRacket, pose: tap)?.angle == 0)
    }
}
