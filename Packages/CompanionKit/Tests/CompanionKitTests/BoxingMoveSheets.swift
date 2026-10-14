#if os(macOS)
import Foundation
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// Preview only (preview/haku-boxing-moves): B1 slip and B2 duck and hook, frame by frame. Never merged.
extension FrameSheets {
    @Test func hakuBoxingMoves() throws {
        let slip = Self.beatStart(kind: 2, lengths: RunnerPose.boxingBeats, every: 24, spread: 6)
        let tap = Self.base
        let rows = [
            Row(label: "B1 摇闪 (2.4 s)", start: slip - 0.2) { AnyView(CompanionView(mode: .boxing, energy: 50)) },
            Row(label: "B2 点按 躲+勾拳 (1.6 s)", start: tap - 0.2) { AnyView(DuckHookFrame(start: tap)) },
        ]
        try write("boxing-B1-B2", rows, frames: 15, step: 0.2)
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

/// HAKU in boxing playing the duck-and-hook poke from `start`, without the card around it.
private struct DuckHookFrame: View {
    let start: Date
    @Environment(\.frameClock) private var frameClock

    var body: some View {
        RunnerFigure(mode: .boxing, pose: pose(at: frameClock ?? start))
            .aspectRatio(RunnerArt.bounds.width / RunnerArt.bounds.height, contentMode: .fit)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 1, green: 0.48, blue: 0.42))
    }

    private func pose(at now: Date) -> RunnerPose {
        let progress = now.timeIntervalSince(start) / WatchPoke.duration
        var pose = RunnerPose(mode: .boxing, time: now.timeIntervalSinceReferenceDate, face: .mid, react: 0)
        if (0..<1).contains(progress) { pose.poke(.duckHook, progress: progress) }
        return pose
    }
}
#endif
