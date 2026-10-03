import HubCore
import Testing

@testable import CompanionKit

@Suite struct CompanionKitTests {
    @Test(arguments: Mode.allCases)
    func everyModeHasBundledArt(_ mode: Mode) {
        #expect(CompanionArt.image(for: mode) != nil)
    }

    @Test func riveValuesMatchTheRunnerViewModel() {
        #expect(Mode.allCases.map(\.riveValue) == ["work", "chill", "box", "money"])
    }

    @Test(arguments: Mode.allCases)
    func idleMotionStaysSmall(_ mode: Mode) {
        for step in 0..<200 {
            let motion = IdleMotion(mode: mode, time: Double(step) * 0.05)
            #expect(abs(motion.dy) <= 8)
            #expect(abs(motion.angle) <= 3)
        }
    }

    @Test func everyModeHasLines() {
        for mode in Mode.allCases {
            #expect(!CompanionLines.lines(for: mode).isEmpty)
        }
        #expect(!CompanionLines.lines(for: nil).isEmpty)
    }
}
