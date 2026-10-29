#if os(iOS) || os(macOS)
import HubCore
import Testing

@testable import CompanionKit

@Suite struct KuroHomeTests {
    @Test func herHairHangsBehindHerTopAndWhatSheHoldsStaysOut() {
        let parts = KuroHomeNode.parts(.chill, items: [], face: .idle, sleeping: false)
        #expect(parts.hair == [.hairBack])
        #expect(parts.torso == [.jacketChill])
        #expect(parts.head.contains(.faceBase) && parts.head.contains(.eyesOpen))
        let all = Set(parts.hair + parts.torso + parts.head)
        #expect(all.isDisjoint(with: [.chillCup, .workTablet, .tennisRacket, .deskBooks, .boxGloveL]))
    }

    @Test func fromBehindSheShowsTheBackOfHerHead() {
        let parts = KuroHomeNode.parts(.tennis, items: [], face: .back, sleeping: false)
        #expect(parts.head.contains(.backHead) && parts.head.contains(.tennisPonytail))
        #expect(!parts.head.contains(.faceBase))
    }

    @Test func asleepSheHasHerNapFaceAndTakesHerGlassesOff() {
        let parts = KuroHomeNode.parts(.desk, items: [], face: .closed, sleeping: true)
        #expect(parts.head.contains(.eyesClosed) && parts.head.contains(.napMouth))
        #expect(!parts.head.contains(.deskGlasses))
        #expect(parts.torso == [.jacketDesk])
    }

    @Test func atHomeSheWearsTheTopSheBoughtFrontAndBack() {
        let front = KuroHomeNode.parts(.work, items: [.workBlouse], face: .idle, sleeping: false)
        #expect(front.torso.contains(.topWorkSailor) && !front.torso.contains(.jacketWork))
        let back = KuroHomeNode.parts(.work, items: [.workBlouse], face: .back, sleeping: false)
        #expect(back.torso == [.topWorkSailorBack])
        #expect(KuroHomeNode.parts(.work, items: [], face: .back, sleeping: false).torso.isEmpty)
        let rain = KuroHomeNode.parts(.work, items: [.rain], face: .back, sleeping: false)
        #expect(rain.torso == [.setRainBack] && rain.head.contains(.setRainHat))
        #expect(back.head.contains(.catEars) && back.head.contains(.backHead) && !rain.head.contains(.catEars))
    }

    @Test func herSleevesMatchTheTopSheBought() {
        #expect(KuroHomeNode.sleeve(.chill, items: []) == KuroHomeNode.sleeve(.chill))
        #expect(KuroHomeNode.sleeve(.chill, items: [.chillCardigan]) == 0xFFD1DC)
        #expect(KuroHomeNode.sleeve(.desk, items: [.sideDenim]) == 0x7FB7FF)
        #expect(KuroHomeNode.sleeve(.work, items: [.workBlouse]) == 0xFFFFFF)
        // A top shows only in its own mode.
        #expect(KuroHomeNode.sleeve(.chill, items: [.sideDenim]) == KuroHomeNode.sleeve(.chill))
    }

    @Test func herForehandGoesBackSweepsAndComesBack() {
        #expect(KuroHomeNode.forehand(0.2) == 0)
        #expect(KuroHomeNode.forehand(0.9) == 1)
        #expect(abs(KuroHomeNode.forehand(1.6) - KuroHomeNode.forehand(0)) < 1e-9)
        #expect(KuroHomeNode.forehand(0.62) > 0 && KuroHomeNode.forehand(0.62) < 1)
    }

    @Test func atHomeSheWearsTheGlovesSheBought() {
        #expect(KuroHomeNode.glove([]) == .boxGloveR)
        #expect(KuroHomeNode.glove([.pinkGloves]) == .itemGlovePinkR)
        #expect(KuroHomeNode.glove([.pinkGloves, .goldGloves]) == .itemGloveGoldR)
    }

    @Test func atHomeHerRedGlassesComeOffForBed() {
        let awake = KuroHomeNode.parts(.study, items: [.redGlasses], face: .idle, sleeping: false)
        #expect(awake.head.contains(.itemGlassesRed))
        let asleep = KuroHomeNode.parts(.study, items: [.redGlasses], face: .closed, sleeping: true)
        #expect(!asleep.head.contains(.itemGlassesRed))
    }

    @Test func atHomeSheWearsTheGogglesAndHeadphonesSheBought() {
        let ski = KuroHomeNode.parts(.ski, items: [.sakuraGoggles], face: .idle, sleeping: false)
        #expect(ski.head.contains(.itemGogglesSakura) && !ski.head.contains(.skiGoggles))
        let dance = KuroHomeNode.parts(.dance, items: [.goldPhones], face: .idle, sleeping: false)
        #expect(dance.head.contains(.itemPhonesGold))
        let asleep = KuroHomeNode.parts(.ski, items: [.sakuraGoggles], face: .closed, sleeping: true)
        #expect(!asleep.head.contains(.itemGogglesSakura))
    }

    @MainActor @Test func theHomeDrawsHerForHerPersona() {
        #expect(CompanionKit.HomeScene.figure(for: .kuro) is KuroHomeNode)
        #expect(CompanionKit.HomeScene.figure(for: .haku) is HakuNode)
    }
}
#endif
