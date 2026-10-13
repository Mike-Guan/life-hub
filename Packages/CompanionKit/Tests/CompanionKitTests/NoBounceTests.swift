import SwiftUI
import Testing

@testable import CompanionKit

/// The tap squash and the hop pass their rest value once on the way back and never spring past it.
struct NoBounceTests {
    private func samples<Value>(_ timeline: KeyframeTimeline<Value>) -> [Value] {
        stride(from: 0.0, through: timeline.duration + 0.05, by: 0.01).map { timeline.value(time: $0) }
    }

    @Test func tapSquashSettlesWithoutOvershoot() {
        let values = samples(KeyframeTimeline(initialValue: Squash()) { Squash.tap() })
        #expect(values.allSatisfy { $0.x >= 1 && $0.x <= 1.08 })
        #expect(values.allSatisfy { $0.y <= 1 && $0.y >= 0.89 })
        #expect(values.last?.x == 1 && values.last?.y == 1)
    }

    @Test func jumpLandsWithoutBounce() {
        let values = samples(KeyframeTimeline(initialValue: 0.0) { Squash.jump() })
        let peak = values.indices.max { values[$0] < values[$1] }!
        #expect(abs(values[peak] - 36) < 0.5)
        // After the peak it only comes down, and it never dips below the floor.
        #expect(zip(values[peak...], values[(peak + 1)...]).allSatisfy { $1 <= $0 + 0.0001 })
        #expect(values[peak...].allSatisfy { $0 >= -0.0001 })
        // The only dip is the short crouch before the jump.
        #expect(values.min()! >= -1.5 - 0.0001)
    }
}
