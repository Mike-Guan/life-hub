#if os(macOS)
import Foundation
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// Preview only (preview/haku-idle-beats): the three new idles H4, H5 and H13 frame by frame. Never merged.
extension FrameSheets {
    @Test func hakuIdleBeats() throws {
        // Round 2 check (UI 审核): the pillow moves from the hug layer to the lean layer at phase 1.85 s.
        let start = Self.beatStart(kind: 2, lengths: RunnerPose.chillBeats, every: 14, spread: 3)
        let row = Row(label: "H5 (PR #364) 1.80/1.85/1.90", start: start + 1.8) {
            AnyView(CompanionView(mode: .chill, energy: 50))
        }
        try write("idle-beats-H5-swap", [row], size: CGSize(width: 360, height: 480), frames: 3, step: 0.05)
    }

    /// The first time after `base` that beat `kind` starts.
    static func beatStart(
        kind: Int, lengths: [TimeInterval], every: TimeInterval, spread: TimeInterval
    ) -> Date {
        let t0 = base.timeIntervalSinceReferenceDate
        let t = (0..<60_000).lazy.map { t0 + Double($0) * 0.01 }.first { t in
            let beat = IdleClock.beat(at: t, every: every, spread: spread, lengths: lengths, seed: RunnerPose.seed)
            return beat.map { $0.kind == kind && $0.phase < 0.01 } ?? false
        }
        return Date(timeIntervalSinceReferenceDate: t ?? t0)
    }
}
#endif
