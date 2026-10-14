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

    // The B2 line in three languages (ja and en are drafts until the copy threads sign them off).
    static let duckHookLines = [("zh", "……反射。"), ("ja", "……つい、反射で。"), ("en", "…Pure reflex.")]

    @Test func hakuDuckHookBubbles() throws {
        let tap = Self.base
        let sizes = [
            ("phone", CGSize(width: 361, height: 260)), ("phoneSE", CGSize(width: 320, height: 240)),
            ("watch46", CGSize(width: 198, height: 242)),
        ]
        for (name, size) in sizes {
            let rows = Self.duckHookLines.map { lang, line in
                Row(label: "B2 \(name) \(lang)", start: tap + 0.6) {
                    AnyView(DuckHookFrame(start: tap, line: line, watch: name.hasPrefix("watch")))
                }
            }
            try write("boxing-B2-bubble-\(name)", rows, size: size, frames: 4, step: 0.2)
        }
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

/// HAKU playing the duck-and-hook poke from `start`; with `line`, laid out like CompanionView with a bubble.
private struct DuckHookFrame: View {
    let start: Date
    var line: String?
    var watch = false
    @Environment(\.frameClock) private var frameClock

    var body: some View {
        if let line {
            ZStack {
                Rectangle().fill(Mode.boxing.color)
                RunnerFigure(mode: .boxing, pose: pose(at: frameClock ?? start))
                    .aspectRatio(RunnerArt.bounds.width / RunnerArt.bounds.height, contentMode: .fit)
                    .padding(.top, 24)
                    .padding(.horizontal, 12)
                    .modifier(WatchFigureFrame(isEnabled: watch))
                SpeechBubble(text: line)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: watch ? .bottom : .topLeading)
            }
        } else {
            RunnerFigure(mode: .boxing, pose: pose(at: frameClock ?? start))
                .aspectRatio(RunnerArt.bounds.width / RunnerArt.bounds.height, contentMode: .fit)
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 1, green: 0.48, blue: 0.42))
        }
    }

    private func pose(at now: Date) -> RunnerPose {
        let progress = now.timeIntervalSince(start) / WatchPoke.duration
        var pose = RunnerPose(mode: .boxing, time: now.timeIntervalSinceReferenceDate, face: .mid, react: 0)
        if (0..<1).contains(progress) { pose.poke(.duckHook, progress: progress) }
        return pose
    }
}
#endif
