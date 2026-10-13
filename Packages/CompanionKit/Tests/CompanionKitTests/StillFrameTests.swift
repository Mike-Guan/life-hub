import Foundation
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// QA S8 (Mike's bug G9): the watch stuttered when its screen came on and froze mid-move when it dimmed.
@Suite struct StillFrameTests {
    @Test func theFrameClockStopsWhenDimmedOrNotActive() {
        let awake = CompanionView.paused(reduceMotion: false, scenePhase: .active, dozing: false, settling: false)
        #expect(!awake)
        for phase in [ScenePhase.inactive, .background] {
            #expect(CompanionView.paused(reduceMotion: false, scenePhase: phase, dozing: false, settling: false))
        }
        #expect(CompanionView.paused(reduceMotion: false, scenePhase: .active, dozing: true, settling: false))
        #expect(CompanionView.paused(reduceMotion: false, scenePhase: .active, dozing: false, settling: true))
        #expect(CompanionView.paused(reduceMotion: true, scenePhase: .active, dozing: false, settling: false))
    }

    // UI HAKU-07/35: with Reduce Motion the character still shows in the mode's look, only without moving.
    @Test(arguments: Mode.allCases)
    func reducedMotionStillDrawsHaku(_ mode: Mode) {
        let eyes: [Mode: RunnerPart] = [.work: .eyesWork, .chill: .eyesChill, .boxing: .cateyeL, .money: .eyesMoney]
        let still = RunnerPose(face: .mid)
        let parts = Set(RunnerFigure.parts(for: mode, pose: still))
        #expect(parts.isSuperset(of: RunnerFigure.baseParts))
        #expect(parts.contains(eyes[mode] ?? .faceBase))
        #expect(still.lean == 0 && still.bounce == 0 && still.shift == 0)
    }

    @Test(arguments: KuroLook.allCases)
    func reducedMotionStillDrawsKuro(_ look: KuroLook) {
        #expect(KuroView.holdsStill(reduceMotion: true, unboxing: false, dozing: false))
        let parts = Set(KuroFigure.parts(for: look, pose: KuroPose(look: look, energy: 50)))
        #expect(parts.isSuperset(of: [.hairBack, .faceBase, .hairFringe, .catEars]))
    }

    // KURO-04: with the watch screen dimmed she dozes standing as in the first idle frame, not mid-hop.
    @Test(arguments: KuroLook.allCases)
    func dimmedKuroDozesInHerRestingFrame(_ look: KuroLook) {
        #expect(KuroView.holdsStill(reduceMotion: false, unboxing: false, dozing: true))
        #expect(!KuroView.holdsStill(reduceMotion: false, unboxing: false, dozing: false))
        let first = KuroView.motion(look, time: 0)
        #expect(first.dy == 0 && first.angle == 0)
        let rest = KuroPose(look: look, energy: 50)
        let dozing = rest.showing(.closed)
        #expect(KuroPart.allCases.allSatisfy { KuroFigure.shift($0, pose: dozing) == .zero })
        let eyes: Set<KuroPart> = [.eyesOpen, .eyesBright, .eyesDown, .eyesClosed]
        let dozed = Set(KuroFigure.parts(for: look, pose: dozing))
        #expect(dozed.contains(.eyesClosed))
        #expect(dozed.subtracting(eyes) == Set(KuroFigure.parts(for: look, pose: rest)).subtracting(eyes))
    }
}
