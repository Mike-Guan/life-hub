import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct CommuteSceneTests {
    @Test @MainActor func walkingToWorkCarriesTheToteAndYawns() {
        var pose = RunnerPose(mode: .chill, time: 0, face: .mid, react: 0)
        pose.commute(CommutePhase(leg: .toWork, stage: .walking, since: .now), time: 0.6)
        let parts = Set(RunnerFigure.parts(for: .chill, pose: pose))
        #expect(parts.isSuperset(of: [.toteBag, .walkDust, .mouthYawn]))
        #expect(!parts.contains(.mouthSmile))
    }

    @Test @MainActor func goingHomeIsSleepyAndSlow() {
        var pose = RunnerPose(mode: .chill, time: 0, face: .mid, react: 0)
        pose.commute(CommutePhase(leg: .home, stage: .walking, since: .now), time: 0.2)
        let parts = Set(RunnerFigure.parts(for: .chill, pose: pose))
        #expect(parts.contains(.eyesSleepy))
        #expect(!parts.contains(.eyesChill))
        #expect(pose.bagLift == 1)
    }

    @Test @MainActor func onTheTrainThereIsNoStepping() {
        var pose = RunnerPose(mode: .chill, time: 0, face: .mid, react: 0)
        pose.commute(CommutePhase(leg: .home, stage: .onTransit, since: .now), time: 0.8)
        let parts = Set(RunnerFigure.parts(for: .chill, pose: pose))
        #expect(!parts.contains(.walkDust))
        #expect(pose.walkFrom == nil)
    }
}
