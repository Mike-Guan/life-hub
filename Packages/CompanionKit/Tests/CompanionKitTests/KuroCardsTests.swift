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
        #expect(KuroLook(mode: .boxing, card: .tennis) == .tennis)
        // No card, or one she has no look for yet, keeps her tennis day.
        #expect(KuroLook(mode: .boxing) == .tennis && KuroLook(mode: .boxing, card: .swimming) == .tennis)
        // The card only changes the card slot.
        #expect(KuroLook(mode: .work, card: .boxing) == .work && KuroLook(mode: .money, card: .art) == .desk)
    }

    @Test func eachCardLookDrawsItsOwnThings() {
        let expected: [KuroLook: Set<KuroPart>] = [
            .box: [.jacketBox, .boxHeadband, .boxGloveL, .boxGloveR],
            .fitness: [.jacketTennis, .gymBlock, .tennisPonytail],
            .study: [.jacketChill, .studyNotebook, .studyHighlighter],
            .art: [.jacketSmock, .workTablet, .craftPen],
            .dance: [.jacketTennis, .tennisPonytail],
            .music: [.jacketChill, .scoreSheet, .scoreFinger],
            .ski: [.jacketTennis, .skiGoggles, .tennisPonytail],
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
}
