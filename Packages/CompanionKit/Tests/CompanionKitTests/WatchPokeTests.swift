import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct WatchPokeTests {
    @Test func eachModeHasItsOwnPoke() {
        let picks = Mode.allCases.map { WatchPoke.pick(mode: $0, energy: 50, asleep: false, busy: false) }
        #expect(picks == [.headsetUp, .clink, .punch, .codeFlash])
    }

    @Test(arguments: Mode.allCases)
    func sleepyHakuRollsOverAndBusyHakuGlares(_ mode: Mode) {
        #expect(WatchPoke.pick(mode: mode, energy: 50, asleep: true, busy: true) == .rollOver)
        #expect(WatchPoke.pick(mode: mode, energy: 10, asleep: false, busy: false) == .rollOver)
        #expect(WatchPoke.pick(mode: mode, energy: nil, asleep: false, busy: true) == .glare)
    }

    @Test func pokesSaySomethingOnlyWhereThePreviewDoes() {
        #expect(WatchPoke.glare.line == "……干嘛。")
        #expect(WatchPoke.headsetUp.line == "在上班。")
        #expect(WatchPoke.clink.line == "叮。")
        #expect([WatchPoke.punch, .codeFlash, .rollOver].allSatisfy { $0.line == nil })
    }

    @Test func fivePokesInARowTurnHakuAway() {
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        let four = (0..<4).map { now.addingTimeInterval(Double(-$0 * 5)) }
        #expect(!CompanionView.pestered(four, now: now, count: WatchPoke.tooMany))
        #expect(CompanionView.pestered(four + [now.addingTimeInterval(-25)], now: now, count: WatchPoke.tooMany))
        let stale = now.addingTimeInterval(-CompanionView.pesterWindow)
        #expect(!CompanionView.pestered(four + [stale], now: now, count: WatchPoke.tooMany))
    }

    @Test func reactionsHoldThenSettleBack() {
        #expect(WatchPoke.hold(0) == 0)
        #expect(WatchPoke.hold(0.4) == 1)
        #expect(WatchPoke.hold(1) == 0)
    }

    @Test func pokesMoveThePropsAndSettle() {
        var work = RunnerPose()
        work.poke(.headsetUp, progress: 0.4)
        #expect(work.cupRUp == 1 && work.eyesDx == 2)
        var chill = RunnerPose()
        chill.poke(.clink, progress: 0.4)
        #expect(chill.canScale > 1 && chill.canOffset.height < 0)
        var boxing = RunnerPose()
        boxing.poke(.punch, progress: 0.4)
        #expect(boxing.gloveRScale > 2 && boxing.lean > 0)
        var done = RunnerPose()
        done.poke(.clink, progress: 1)
        #expect(done.canScale == 1 && done.canOffset == .zero)
    }

    @Test func pokesSwapTheirParts() {
        var glare = RunnerPose()
        glare.poke(.glare, progress: 0.1)
        let startled = Set(RunnerFigure.parts(for: .chill, pose: glare))
        #expect(startled.isSuperset(of: [.eyesWork, .lidsWork, .browsWork, .ouchLines, .monsterCan]))
        #expect(startled.isDisjoint(with: [.eyesChill, .mouthSmile]))
        glare.poke(.glare, progress: 0.6)
        #expect(!RunnerFigure.parts(for: .chill, pose: glare).contains(.ouchLines))

        var code = RunnerPose()
        code.poke(.codeFlash, progress: 0.4)
        let money = Set(RunnerFigure.parts(for: .money, pose: code))
        #expect(money.isSuperset(of: [.ledCode, .codeBits]) && !money.contains(.ledYen))
        code.poke(.codeFlash, progress: 1)
        #expect(RunnerFigure.parts(for: .money, pose: code).contains(.ledYen))

        var punch = RunnerPose()
        punch.poke(.punch, progress: 0.4)
        #expect(RunnerFigure.parts(for: .boxing, pose: punch).contains(.thumpLines))
    }

    @Test(arguments: WatchPoke.allCases)
    func pokedPartsKeepDrawingOrder(_ kind: WatchPoke) {
        var pose = RunnerPose()
        pose.poke(kind, progress: 0.2)
        for mode in Mode.allCases {
            let order = RunnerFigure.parts(for: mode, pose: pose).compactMap { RunnerPart.allCases.firstIndex(of: $0) }
            #expect(order == order.sorted())
        }
    }
}
