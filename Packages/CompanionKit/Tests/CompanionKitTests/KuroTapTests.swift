import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct KuroTapTests {
    @Test func eachLookHasItsOwnMoveAndSleepyMeansRubbing() {
        let moves = KuroLook.allCases.map { KuroTap(look: $0, sleepy: false) }
        let own: [KuroTap] = [.tablet, .sip, .swing, .glasses, .bump, .hug, .mark, .sketch]
        // The later cards all hug for now.
        #expect(moves == own + Array(repeating: KuroTap.hug, count: 7))
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

    // 动作展示总表 G2: she squashes edge-on to swap sides as she turns away and back, and the bubble waits.
    @Test func sheFlipsLikeACardToTurnAway() {
        let pose = KuroPose(look: .chill, energy: nil)
        let length = KuroTap.turnAway.duration
        let at = { (t: Double) in t / length }
        let edge = { (t: Double) in abs(KuroTap.turnWidth(at(t)) - KuroTap.edgeOn) < 0.001 }
        #expect(KuroTap.turnWidth(0) == 1 && edge(0.12) && KuroTap.turnWidth(at(0.5)) == 1 && edge(length - 0.12))
        #expect(KuroView.width((.turnAway, at(0.06))) < 1 && KuroView.width((.sip, 0.05)) == 1)
        let front = Set(KuroFigure.parts(for: .chill, pose: pose.reacting(.turnAway, progress: at(0.1))))
        #expect(front.contains(.faceBase) && !front.contains(.backHead))
        let back = Set(KuroFigure.parts(for: .chill, pose: pose.reacting(.turnAway, progress: at(0.2))))
        #expect(back.contains(.backHead) && !back.contains(.tapDots))
        #expect(KuroTap.dotsOpacity(at(0.29)) > 0 && KuroTap.dotsOpacity(at(0.29)) < 1)
        #expect(KuroTap.dotsOpacity(at(1.5)) == 1 && KuroTap.dotsOpacity(at(length - 0.2)) == 0)
        let turning = pose.reacting(.turnAway, progress: at(1.5))
        #expect(KuroFigure.opacity(.tapDots, pose: turning) == 1)
        let turnedBack = pose.reacting(.turnAway, progress: at(2.95))
        #expect(KuroFigure.parts(for: .chill, pose: turnedBack).contains(.faceBase))
    }

    // 动作展示总表 G1: her eyes shut for a moment at the end instead of jumping back to her own.
    @Test func aTapEndsWithHerEyesShutWhenTheyChange() {
        let pose = KuroPose(look: .work, energy: nil)
        #expect(pose.reacting(.tablet, progress: 0.9).eyes == .down)
        #expect(pose.reacting(.tablet, progress: 0.97).eyes == .closed)
        let desk = KuroPose(look: .desk, energy: nil)
        #expect(desk.reacting(.glasses, progress: 0.97).eyes == desk.eyes)
        #expect(pose.reacting(.turnAway, progress: 0.99).eyes == pose.eyes)
    }

    // 动作展示总表 G4: her blanket slides down and away as the cup comes up, and back up after it is down.
    @Test func herLapSlidesAwayForTheSip() {
        var pose = KuroPose(look: .chill, energy: nil)
        pose.items = [.blanket]
        let at = { (t: Double) in pose.reacting(.sip, progress: t / KuroTap.sip.duration) }
        let leaving = KuroFigure.shift(.itemBlanket, pose: at(0.1)).height
        #expect(KuroFigure.parts(for: .chill, pose: at(0.1)).contains(.itemBlanket))
        #expect(leaving > 0 && leaving < KuroTap.lapDrop)
        #expect(!KuroFigure.parts(for: .chill, pose: at(0.5)).contains(.itemBlanket))
        #expect(!KuroFigure.parts(for: .chill, pose: at(0.82)).contains(.itemBlanket))
        let coming = KuroFigure.shift(.itemBlanket, pose: at(0.92)).height
        #expect(KuroFigure.parts(for: .chill, pose: at(0.92)).contains(.itemBlanket))
        #expect(coming > 0 && coming < KuroTap.lapDrop)
        #expect(KuroFigure.shift(.itemBlanket, pose: at(1.05)) == .zero)
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
        // UI 审核 C9 round 1: never two right hands. Her tucking hand goes down and away, then the pen comes up.
        let handDown = tap.cutting((.tuck, 0.5), back: 0.25)
        #expect(KuroFigure.shift(.idleTuckHand, pose: handDown).height > 1)
        #expect(KuroFigure.opacity(.idleTuckHand, pose: handDown) == 1)
        #expect(KuroFigure.shift(.craftPen, pose: handDown).height > 40)
        let penUp = tap.cutting((.tuck, 0.5), back: 0.75)
        #expect(KuroFigure.opacity(.idleTuckHand, pose: penUp) == 0)
        let halfway = KuroFigure.shift(.craftPen, pose: penUp).height
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

    // 动作展示总表 G15 (精修第 2 批, Mike 2026-10-17).
    @Test func theTabletSlidesBackToHerLapAtTheEnd() {
        let pose = KuroPose(look: .work, energy: nil)
        #expect(KuroTap.tabletDown(0.7) == 0 && KuroTap.tabletDown(0.999) > 0.99)
        let late = pose.reacting(.tablet, progress: 0.9)
        let parts = KuroFigure.parts(for: .work, pose: late)
        #expect(parts.contains(.tapTablet) && parts.contains(.workTablet))
        let fading = KuroFigure.opacity(.tapTablet, pose: late) + KuroFigure.opacity(.workTablet, pose: late)
        #expect(abs(fading - 1) < 0.001 && KuroFigure.opacity(.workTablet, pose: late) > 0)
        let early = pose.reacting(.tablet, progress: 0.7)
        #expect(!KuroFigure.parts(for: .work, pose: early).contains(.workTablet))
        #expect(KuroFigure.shift(.tapTablet, pose: late).height > KuroFigure.shift(.tapTablet, pose: early).height)
    }

    // 动作展示总表 C5 (精修第 2 批).
    @Test func herLapSlidesAwayWhileSheBlowsOnHerDrink() {
        var pose = KuroPose(look: .chill, energy: nil)
        pose.items = [.blanket]
        let at = { (p: Double) in pose.idling((.blow, p)) }
        #expect(KuroFigure.parts(for: .chill, pose: at(0.03)).contains(.itemBlanket))
        #expect(KuroFigure.shift(.itemBlanket, pose: at(0.03)).height > 0)
        #expect(!KuroFigure.parts(for: .chill, pose: at(0.5)).contains(.itemBlanket))
        let back = KuroFigure.parts(for: .chill, pose: at(0.95))
        #expect(back.contains(.itemBlanket) && back.contains(.chillCup) && !back.contains(.tapCup))
        #expect(KuroFigure.shift(.itemBlanket, pose: at(0.95)).height > 0)
        #expect(KuroFigure.shift(.itemBlanket, pose: at(0.999)).height < 1)
    }

    // 动作展示总表 C7 (精修第 2 批).
    @Test func theFlatRacketFlipsBackUprightAfterTheJuggle() {
        let pose = KuroPose(look: .tennis, energy: nil)
        let at = { (p: Double) in pose.idling((.juggle, p)) }
        #expect(KuroFigure.turn(.juggleRacket, pose: at(0.5))?.scale == 1)
        let flat = KuroFigure.parts(for: .tennis, pose: at(0.94))
        #expect(flat.contains(.juggleRacket) && !flat.contains(.tapBall) && !flat.contains(.tennisRacket))
        #expect((KuroFigure.turn(.juggleRacket, pose: at(0.95))?.scale ?? 1) < 0.5)
        let upright = KuroFigure.parts(for: .tennis, pose: at(0.97))
        #expect(upright.contains(.tennisRacket) && !upright.contains(.juggleRacket))
        let opening = KuroFigure.turn(.tennisRacket, pose: at(0.97))?.scale ?? 1
        #expect(opening < 0.5 && opening >= KuroTap.edgeOn)
        #expect((KuroFigure.turn(.tennisRacket, pose: at(0.999))?.scale ?? 0) > 0.99)
    }

    // 动作展示总表 G6 / KURO.md C8 (精修第 2 批).
    @Test func onTheWatchTheRaisedRacketSwingsTwirlsAndJugglesHigher() {
        let pose = KuroPose(look: .tennis, energy: nil)
        let swing = KuroFigure.turn(.watchRacket, pose: pose.reacting(.swing, progress: 0.4))
        #expect(swing?.angle == -75 && swing?.pivot == CGPoint(x: 111, y: 108))
        #expect((KuroFigure.turn(.watchRacket, pose: pose.idling((.twirl, 0.35)))?.scale ?? 1) < -0.9)
        #expect(KuroFigure.shift(.watchRacket, pose: pose.idling((.twirl, 0.85))).height < -5)
        let juggling = pose.idling((.juggle, 0.25))
        #expect(KuroFigure.parts(for: .tennis, pose: juggling, watch: true).contains(.juggleRacket))
        let phone = KuroFigure.offset(.tapBall, pose: juggling).height
        #expect(KuroFigure.offset(.tapBall, pose: juggling, watch: true).height == phone - KuroFigure.watchJuggleLift)
    }

    // 动作展示总表 C14 (精修第 2 批): at bedtime a tap rolls her over instead of rubbing an eye.
    @Test func asleepSheRollsOverWithHerEyesShut() {
        #expect(KuroTap.rollOver.duration == 1.4)
        let pose = KuroPose(look: .chill, energy: nil, bedtime: .on)
        for p in [0.1, 0.5, 0.97] { #expect(pose.reacting(.rollOver, progress: p).eyes == .closed) }
        #expect(KuroView.hop((.rollOver, 0.1)) == 0)
        let leaning = KuroView.rollOver((.rollOver, 0.5), time: 0)
        #expect(abs((leaning?.angle ?? 0) - 8) < 0.001)
        #expect(KuroView.rollOver((.rub, 0.5), time: 0) == nil && KuroView.rollOver(nil, time: 0) == nil)
        #expect(KuroView.wink == 0.15)
    }

    @Test func asleepOrNappingSheRollsOverWithoutAHeart() {
        var napping = KuroPose(look: .chill, energy: nil)
        napping.napping = true
        let rolled = napping.reacting(.rollOver, progress: 0.5, heart: true)
        #expect(!rolled.heart && rolled.eyes == .closed)
        #expect(KuroFigure.parts(for: .chill, pose: rolled).contains(.napTablet))
        #expect(KuroPose(look: .chill, energy: nil).reacting(.sip, progress: 0.5, heart: true).heart)
    }
}
