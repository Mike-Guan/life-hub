import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// UI 审核 HAKU-19: hands and props used to pop in and out in one frame.
struct HandInTests {
    @Test func thePhoneComesUpAndGoesDownAgain() throws {
        let start = try #require(IdleClockTests.firstStart(kind: 1, lengths: RunnerPose.workBeats))
        let rising = RunnerPose(mode: .work, time: start + 0.1, face: .mid, react: 0)
        #expect(rising.phoneGlance && rising.handIn > 0 && rising.handIn < 1)
        #expect(RunnerPose(mode: .work, time: start + 0.7, face: .mid, react: 0).handIn == 1)
        let lowering = RunnerPose(mode: .work, time: start + 1.1, face: .mid, react: 0)
        #expect(lowering.handIn > 0 && lowering.handIn < 1)
    }

    @Test func theScratchingHandComesUpAndGoesDownAgain() throws {
        let start = try #require(IdleClockTests.firstStart(kind: 1, lengths: RunnerPose.chillBeats))
        let reaching = RunnerPose(mode: .chill, time: start + 0.1, face: .mid, react: 0)
        #expect(reaching.scratch >= 0 && reaching.handIn > 0 && reaching.handIn < 1)
        #expect(RunnerPose(mode: .chill, time: start + 1, face: .mid, react: 0).handIn == 1)
        let leaving = RunnerPose(mode: .chill, time: start + 1.9, face: .mid, react: 0)
        #expect(leaving.handIn > 0 && leaving.handIn < 1)
    }

    @Test func theWatchComesUpBeforeTheTapAndGoesDownAfter() {
        var start = RunnerPose(face: .mid)
        start.cue(DailyCue(stage: .soon, prop: .note, id: "a"), time: 0.1, slap: nil)
        #expect(start.watchTap && start.handIn > 0 && start.handIn < 1)
        var tapping = RunnerPose(face: .mid)
        tapping.cue(DailyCue(stage: .soon, prop: .note, id: "a"), time: 1.2, slap: nil)
        #expect(tapping.handIn == 1)
        var done = RunnerPose(face: .mid)
        done.cue(DailyCue(stage: .soon, prop: .note, id: "a"), time: 2.3, slap: nil)
        #expect(done.handIn > 0 && done.handIn < 1)
    }

    @Test func theCanGoesDownBeforeTheCuesPropComesUp() {
        let cue = DailyCue(stage: .now, prop: .note, id: "b")
        var first = RunnerPose(face: .mid)
        first.cue(cue, time: 5, slap: nil, entered: 0)
        #expect(first.canOpacity == 1 && first.propRaise == 0)
        #expect(RunnerFigure.parts(for: .chill, pose: first).contains(.monsterCan))
        var going = RunnerPose(face: .mid)
        going.cue(cue, time: 5, slap: nil, entered: 0.3)
        #expect(going.canOpacity > 0 && going.canOpacity < 1 && going.propRaise == 0)
        var rising = RunnerPose(face: .mid)
        rising.cue(cue, time: 5, slap: nil, entered: 0.75)
        #expect(rising.canOpacity == 0 && rising.propRaise > 0 && rising.propRaise < 1)
        var held = RunnerPose(face: .mid)
        held.cue(cue, time: 5, slap: nil)
        let parts = Set(RunnerFigure.parts(for: .chill, pose: held))
        #expect(held.propRaise == 1 && !parts.contains(.monsterCan) && parts.contains(.stickyNote))
    }
}
