import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct KuroIdleTests {
    // KURO-12 (UI 审核 2026-10-08): her own small moves, not HAKU's headphone nod or a sleeping breath.
    @Test(arguments: KuroLook.allCases)
    func everyLookHasHerOwnMovesAndAllOfThemShow(_ look: KuroLook) {
        let seen = Set(stride(from: 0.0, to: 1_200, by: 0.1).compactMap { KuroIdle.at($0, look: look)?.0 })
        #expect(seen == Set(KuroIdle.pool(look)))
        #expect(KuroIdle.pool(look).contains(.ears))
    }

    @Test(arguments: KuroIdle.allCases)
    func everyMoveMovesSomethingAndEndsWhereItStarted(_ move: KuroIdle) throws {
        let look = try #require(KuroLook.allCases.first { KuroIdle.pool($0).contains(move) })
        let pose = KuroPose(look: look, energy: 50)
        let resting = KuroFigure.parts(for: look, pose: pose)
        let moved = stride(from: 0.05, to: 1, by: 0.05).contains { p in
            let posed = pose.idling((move, p))
            let parts = KuroFigure.parts(for: look, pose: posed)
            return parts != resting || parts.contains { KuroFigure.shift($0, pose: posed) != .zero }
        }
        #expect(moved)
        let end = pose.idling((move, 0.999))
        #expect(KuroFigure.parts(for: look, pose: end) == resting)
        #expect(resting.allSatisfy { abs(KuroFigure.shift($0, pose: end).height) < 0.1 })
    }

    @Test func aTapWinsOverAnIdleMove() {
        var pose = KuroPose(look: .desk, energy: 50).idling((.pen, 0.25))
        #expect(KuroFigure.shift(.deskPen, pose: pose) != .zero)
        pose = pose.reacting(.glasses, progress: 0.1)
        #expect(KuroFigure.shift(.deskPen, pose: pose) == .zero)
    }

    @Test func herLooksNoLongerBorrowHakusLoops() {
        let times = stride(from: 0.0, to: 20, by: 0.1)
        #expect(times.contains { KuroView.motion(.work, time: $0).dy != IdleMotion(mode: .work, time: $0).dy })
        #expect(times.contains { KuroView.motion(.desk, time: $0).dy != IdleMotion.sleeping(time: $0).dy })
    }

    // KURO-16: a pace change or the end of an unboxing never makes her jump.
    @Test func herIdleRunsOnWhenHerPaceChanges() {
        let pace = IdlePace(time: 0, phase: 0, pace: 1).changing(to: 0.6, at: 1_000)
        #expect(abs(pace.phase(at: 1_000) - 1_000) < 0.0001)
        #expect(abs(pace.phase(at: 1_010) - 1_006) < 0.0001)
        let before = KuroView.motion(.chill, time: 1_000 * 1)
        let after = KuroView.motion(.chill, time: pace.phase(at: 1_000.033))
        #expect(abs(before.dy - after.dy) <= 2 && abs(before.angle - after.angle) < 0.5)
    }

    @Test func afterUnboxingHerIdleEasesBackIn() {
        let end = Date(timeIntervalSinceReferenceDate: 500)
        #expect(KuroView.settle(since: nil, at: 500) == 1)
        #expect(KuroView.settle(since: end, at: 500) == 0)
        #expect(KuroView.settle(since: end, at: 500.25) == 0.5)
        #expect(KuroView.settle(since: end, at: 501) == 1)
    }
}
