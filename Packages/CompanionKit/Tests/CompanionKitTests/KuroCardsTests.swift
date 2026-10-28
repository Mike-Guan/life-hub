import Foundation
import HubCore
import Testing

@testable import CompanionKit

// Identity cards, batch 1 (第 1 批身份卡 预览): the second character dresses for the card the user picked.
@Suite struct KuroCardsTests {
    @Test func theCardSlotDressesHerForThePickedCard() {
        #expect(KuroLook(mode: .boxing, card: .boxing) == .box)
        #expect(KuroLook(mode: .boxing, card: .fitness) == .fitness)
        #expect(KuroLook(mode: .boxing, card: .study) == .study)
        #expect(KuroLook(mode: .boxing, card: .art) == .art)
        #expect(KuroLook(mode: .boxing, card: .dance) == .dance)
        #expect(KuroLook(mode: .boxing, card: .music) == .music)
        #expect(KuroLook(mode: .boxing, card: .ski) == .ski)
        #expect(KuroLook(mode: .boxing, card: .swimming) == .swimming)
        #expect(KuroLook(mode: .boxing, card: .yoga) == .yoga)
        #expect(KuroLook(mode: .boxing, card: .ball) == .ball)
        #expect(KuroLook(mode: .boxing, card: .outdoor) == .outdoor)
        #expect(KuroLook(mode: .boxing, card: .tennis) == .tennis)
        // No card keeps her tennis day.
        #expect(KuroLook(mode: .boxing) == .tennis)
        // The card only changes the card slot.
        #expect(KuroLook(mode: .work, card: .boxing) == .work && KuroLook(mode: .money, card: .art) == .desk)
    }

    @Test func eachCardLookDrawsItsOwnThings() {
        let expected: [KuroLook: Set<KuroPart>] = [
            .box: [.jacketBox, .boxShoulderTowel, .boxHeadband, .boxGloveL, .boxGloveR],
            .fitness: [.jacketTennis, .gymBlock, .tennisPonytail],
            .study: [.jacketChill, .studyNotebook, .studyHighlighter],
            .art: [.jacketSmock, .workTablet, .craftPen],
            .dance: [.jacketTennis, .tennisPonytail],
            .music: [.jacketChill, .scoreSheet, .scoreFinger],
            .ski: [.jacketTennis, .skiGoggles, .tennisPonytail],
            .swimming: [.jacketTennis, .swimGoggles, .tennisPonytail],
            .yoga: [.jacketTennis, .yogaMat, .tennisPonytail],
            .ball: [.jacketTennis, .sportBall, .sportBallHand, .tennisPonytail],
            .outdoor: [.jacketChill, .outBackpack, .outStraps, .outPole],
        ]
        for (look, things) in expected {
            let parts = Set(KuroFigure.parts(for: look, pose: KuroPose(look: look, energy: 50)))
            #expect(parts.isSuperset(of: things), "\(look)")
            // Her tennis racket, cup and glasses stay with their own looks.
            #expect(parts.isDisjoint(with: [.tennisRacket, .chillCup, .deskGlasses, .tennisHeadband]), "\(look)")
            // Mike 2026-10-15: nothing stands in the room by default.
            #expect(parts.isDisjoint(with: [.boxSandbag, .danceSpeaker]), "\(look)")
        }
    }

    @Test func aTapOnTheBoxingCardTapsTheGlovesTogether() {
        let pose = KuroPose(look: .box, energy: 50)
        #expect(pose.reacting(.bump, progress: 0.05).eyes == .surprised)
        #expect(KuroFigure.shift(.boxGloveL, pose: pose.reacting(.bump, progress: 0.05)) == .zero)
        // The gloves meet at a quarter of the way through what follows the start.
        let met = pose.reacting(.bump, progress: 0.15 + 0.85 / 8)
        #expect(KuroFigure.shift(.boxGloveL, pose: met).width > 3 && KuroFigure.shift(.boxGloveR, pose: met).width < -3)
        #expect(met.eyes == .closed)
    }

    // Mike 10/14 (第 1 批身份卡 第 3 轮): boxing is an ordinary card for her; tennis has the new moves.
    @Test func eachCardHasItsOwnIdleMove() {
        #expect(KuroIdle.pool(.box) == [.ears, .gloves, .ponytail])
        #expect(KuroIdle.pool(.fitness).contains(.lap))
        #expect(KuroIdle.pool(.study).contains(.highlight))
        #expect(KuroIdle.pool(.art).contains(.draw))
        #expect(KuroIdle.pool(.tennis) == [.ears, .racket, .ponytail, .juggle, .twirl])
    }

    // Deferred identity cards (顺延身份卡 预览, UI 审核 round 2 passed 2026-10-14).
    @Test func eachDeferredCardHasItsOwnIdleMove() {
        #expect(KuroIdle.pool(.dance) == [.ears, .ponytail, .groove])
        #expect(KuroIdle.pool(.music) == [.ears, .score])
        #expect(KuroIdle.pool(.ski) == [.ears, .snow])
    }

    @Test func theNotesRiseWithoutASpeaker() {
        let pose = KuroPose(look: .dance, energy: 50).idling((.groove, 0.3))
        for watch in [false, true] {
            let parts = KuroFigure.parts(for: .dance, pose: pose, watch: watch)
            #expect(!parts.contains(.danceSpeaker) && parts.contains(.speakerNoteA))
        }
    }

    @Test func dancingTheNotesRiseAndFade() {
        let pose = KuroPose(look: .dance, energy: 50)
        let early = pose.idling((.groove, 0.2))
        let late = pose.idling((.groove, 0.4))
        #expect(KuroFigure.parts(for: .dance, pose: early).contains(.eyesHappy))
        let rise = [early, late].map { KuroFigure.shift(.speakerNoteA, pose: $0).height }
        #expect(rise[1] < rise[0])
        #expect(KuroFigure.opacity(.speakerNoteA, pose: late) < KuroFigure.opacity(.speakerNoteA, pose: early))
        #expect(KuroView.motion(.dance, time: 0.25).angle > 2 && KuroView.motion(.dance, time: 0.75).angle < -2)
    }

    @Test func theFingerTapsFourPlacesOnTheScore() {
        let pose = KuroPose(look: .music, energy: 50)
        // Each tap is at its lowest 0.15 s after it starts, half a second apart.
        let taps = (0..<4).map {
            KuroFigure.shift(.scoreFinger, pose: pose.idling((.score, (0.55 + Double($0) * 0.5) / 3)))
        }
        #expect(Set(taps.map(\.width)).count == 4)
        #expect(taps.allSatisfy { abs($0.height) < 0.5 })
        let lifted = KuroFigure.shift(.scoreFinger, pose: pose.idling((.score, 0.8 / 3)))
        #expect(lifted.height < -3)
        #expect(KuroFigure.parts(for: .music, pose: pose.idling((.score, 0.5))).contains(.eyesDown))
    }

    @Test func theMittenPatsTheSnowOffThenSheSneezes() {
        let pose = KuroPose(look: .ski, energy: 50)
        let pat = pose.idling((.snow, 0.6 / 3))
        #expect(Set(KuroFigure.parts(for: .ski, pose: pat)).isSuperset(of: [.snowBits, .mittenArm, .mittenHand]))
        let falling = pose.idling((.snow, 1.2 / 3))
        #expect(KuroFigure.shift(.snowBits, pose: falling).height > 10)
        #expect(KuroFigure.opacity(.snowBits, pose: falling) < 0.5)
        let sneeze = pose.idling((.snow, 2.2 / 3))
        let parts = Set(KuroFigure.parts(for: .ski, pose: sneeze))
        #expect(parts.isSuperset(of: [.sneezePuff, .eyesClosed]) && !parts.contains(.mittenHand))
        #expect(KuroFigure.shift(.faceBase, pose: sneeze).height > 0)
    }

    // Identity cards, batch 2 (第 2 批身份卡 草稿): each card has its own move and its base outfit's moves.
    @Test func eachBatchTwoCardHasItsOwnIdleMove() {
        #expect(KuroIdle.pool(.swimming) == [.ears, .ponytail, .goggles, .reach])
        #expect(KuroIdle.pool(.yoga) == [.ears, .ponytail, .stretch, .reach, .towel])
        #expect(KuroIdle.pool(.ball) == [.ears, .ponytail, .dribble, .reach, .towel])
        #expect(KuroIdle.pool(.outdoor) == [.ears, .gaze, .collar, .phone])
        #expect(KuroIdle.stretch.length == 2 * KuroIdle.snow.length)
    }

    @Test func theGogglesComeDownThenSnapBackUp() {
        let pose = KuroPose(look: .swimming, energy: 50)
        let on = pose.idling((.goggles, 1 / 2.5))
        #expect(KuroFigure.shift(.swimGoggles, pose: on).height > 25)
        #expect(KuroFigure.parts(for: .swimming, pose: pose.idling((.goggles, 1.05 / 2.5))).contains(.eyesClosed))
        let snapped = pose.idling((.goggles, 1.7 / 2.5))
        #expect(KuroFigure.shift(.swimGoggles, pose: snapped).height < 0.5)
        #expect(Set(KuroFigure.parts(for: .swimming, pose: snapped)).isSuperset(of: [.eyesSurprised, .mouthO]))
    }

    // UI 审核 #569 r1: the bend has to read as one, at least 6° each way, with the mat standing still.
    @Test func sheBendsSideToSideButTheMatStays() {
        let pose = KuroPose(look: .yoga, energy: 50)
        let left = pose.idling((.stretch, 2 / 6))
        let right = pose.idling((.stretch, 4.1 / 6))
        for part in [KuroPart.faceBase, .jacketTennis, .hairBack, .catEars] {
            #expect((KuroFigure.turn(part, pose: left)?.angle ?? 0) <= -6, "\(part)")
            #expect((KuroFigure.turn(part, pose: right)?.angle ?? 0) >= 6, "\(part)")
        }
        #expect(KuroFigure.turn(.yogaMat, pose: left) == nil && KuroFigure.turn(.yogaMat, pose: right) == nil)
        #expect(KuroFigure.shift(.yogaMat, pose: left) == .zero && KuroFigure.shift(.yogaMat, pose: right) == .zero)
        // Upright again before she breathes out, and still between moves.
        #expect((KuroFigure.turn(.faceBase, pose: pose.idling((.stretch, 5.5 / 6)))?.angle ?? 0) == 0)
        #expect(KuroFigure.turn(.faceBase, pose: pose) == nil)
        #expect(KuroFigure.parts(for: .yoga, pose: left).contains(.eyesClosed))
    }

    @Test func theBallBouncesTwiceAndComesBackToHerHand() {
        let pose = KuroPose(look: .ball, energy: 50)
        let lows = [0.55, 1.25].map { KuroFigure.shift(.sportBall, pose: pose.idling((.dribble, $0 / 2.4))).height }
        #expect(lows.allSatisfy { $0 > 15 })
        #expect(KuroFigure.shift(.sportBall, pose: pose.idling((.dribble, 0.9 / 2.4))).height < 1)
        #expect(KuroFigure.parts(for: .ball, pose: pose.idling((.dribble, 0.55 / 2.4))).contains(.eyesDown))
        #expect(KuroFigure.parts(for: .ball, pose: pose.idling((.dribble, 2 / 2.4))).contains(.eyesHappy))
    }

    @Test func outdoorsTheWindCatchesHerEarsAndHair() {
        let pose = KuroPose(look: .outdoor, energy: 50)
        #expect(KuroFigure.shift(.outPole, pose: pose.idling((.gaze, 0.3 / 3.5))).height < -4)
        let looking = pose.idling((.gaze, 1.3 / 3.5))
        #expect(KuroFigure.shift(.eyesOpen, pose: looking).height < -2)
        #expect(KuroFigure.shift(.catEars, pose: looking).height < -2)
        #expect(KuroFigure.shift(.hairBack, pose: looking).width > 0.5)
        #expect(KuroFigure.parts(for: .outdoor, pose: pose.idling((.gaze, 2.8 / 3.5))).contains(.eyesHappy))
    }

    // Walking off she carries her walk backpack, so the outdoor one comes off; the pole goes down with her props.
    @Test func walkingSheSwapsTheOutdoorPackForHerWalkPack() {
        var pose = KuroPose(look: .outdoor, energy: 50)
        pose.scene = .walking(from: .home, time: 0, lookingBack: false)
        let parts = Set(KuroFigure.parts(for: .outdoor, pose: pose))
        #expect(parts.isSuperset(of: [.walkPack, .walkStraps]))
        #expect(parts.isDisjoint(with: [.outBackpack, .outStraps, .outPole]))
    }

    // Mike 2026-10-15: the towel rests on her right shoulder in the boxing look; there is no back view of it.
    @Test func theBoxingTowelStaysOnHerShoulderUntilSheTurns() {
        let pose = KuroPose(look: .box, energy: 50)
        #expect(KuroFigure.parts(for: .box, pose: pose).contains(.boxShoulderTowel))
        #expect(KuroFigure.parts(for: .box, pose: pose, watch: true).contains(.boxShoulderTowel))
        #expect(!KuroFigure.parts(for: .box, pose: pose.reacting(.turnAway, progress: 0.5)).contains(.boxShoulderTowel))
        #expect(!KuroFigure.parts(for: .tennis, pose: KuroPose(look: .tennis, energy: 50)).contains(.boxShoulderTowel))
    }
}
