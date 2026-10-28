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

    @Test func herForehandGoesBackSweepsAndComesBack() {
        #expect(KuroHomeNode.forehand(0.2) == 0)
        #expect(KuroHomeNode.forehand(0.9) == 1)
        #expect(abs(KuroHomeNode.forehand(1.6) - KuroHomeNode.forehand(0)) < 1e-9)
        #expect(KuroHomeNode.forehand(0.62) > 0 && KuroHomeNode.forehand(0.62) < 1)
    }

    @MainActor @Test func theHomeDrawsHerForHerPersona() {
        #expect(CompanionKit.HomeScene.figure(for: .kuro) is KuroHomeNode)
        #expect(CompanionKit.HomeScene.figure(for: .haku) is HakuNode)
    }
}
#endif
