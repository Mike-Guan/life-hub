#if os(macOS)
import Foundation
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// Preview only (preview/polish): before / after frames of the polish PRs for UI 审核. Never merged.
extension FrameSheets {
    @Test func polishTapAndJump() throws {
        let rows = [
            Row(label: "tap 前（bouncy）", start: Self.base) { AnyView(SquashFrame(new: false, start: Self.base)) },
            Row(label: "tap 后（无回弹）", start: Self.base) { AnyView(SquashFrame(new: true, start: Self.base)) },
            Row(label: "jump 前（bouncy）", start: Self.base) { AnyView(JumpFrame(new: false, start: Self.base)) },
            Row(label: "jump 后（无回弹）", start: Self.base) { AnyView(JumpFrame(new: true, start: Self.base)) },
        ]
        try write("polish-1-tap-jump", rows, frames: 16, step: 0.05)
    }

    @Test func polishNod() throws {
        let rows = [
            Row(label: "HAKU 哦。点头", start: Self.base) { AnyView(HakuNodFrame(start: Self.base)) },
            Row(label: "KURO 嗯。点头", start: Self.base) { AnyView(KuroNodFrame(start: Self.base)) },
        ]
        try write("polish-2-nod", rows, frames: 10, step: 0.16)
    }

    @Test func polishModeFade() throws {
        let rows = [
            Row(label: "切模式 前（硬切）", start: Self.base) { AnyView(FadeFrame(fade: false, start: Self.base)) },
            Row(label: "切模式 后（0.3s 淡）", start: Self.base) { AnyView(FadeFrame(fade: true, start: Self.base)) },
        ]
        try write("polish-3-mode-fade", rows, frames: 10, step: 0.05)
    }

    struct SquashFrame: View {
        let new: Bool
        let start: Date
        @Environment(\.frameClock) private var clock

        var body: some View {
            let t = (clock ?? start).timeIntervalSince(start)
            let value =
                new
                ? KeyframeTimeline(initialValue: Squash()) { Squash.tap() }.value(time: t)
                : KeyframeTimeline(initialValue: Squash()) {
                    KeyframeTrack(\.x) {
                        CubicKeyframe(1.07, duration: 0.08)
                        SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                    }
                    KeyframeTrack(\.y) {
                        CubicKeyframe(0.9, duration: 0.08)
                        SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                    }
                }.value(time: t)
            VStack(spacing: 2) {
                RunnerFigure(mode: .chill, pose: RunnerPose(face: .mid))
                    .scaleEffect(x: value.x, y: value.y, anchor: .bottom)
                Text(String(format: "x %.3f  y %.3f", value.x, value.y)).font(.system(size: 11, design: .monospaced))
            }
            .padding(10)
            .background(Mode.chill.color)
        }
    }

    struct JumpFrame: View {
        let new: Bool
        let start: Date
        @Environment(\.frameClock) private var clock

        var body: some View {
            let t = (clock ?? start).timeIntervalSince(start)
            let lift =
                new
                ? KeyframeTimeline(initialValue: 0.0) { Squash.jump() }.value(time: t)
                : KeyframeTimeline(initialValue: 0.0) {
                    KeyframeTrack {
                        CubicKeyframe(0, duration: 0.05)
                        SpringKeyframe(36, duration: 0.18)
                        SpringKeyframe(0, duration: 0.45, spring: .bouncy)
                    }
                }.value(time: t)
            VStack(spacing: 2) {
                RunnerFigure(mode: .chill, pose: RunnerPose(face: .high))
                    .offset(y: -lift)
                Text(String(format: "lift %.1f", lift)).font(.system(size: 11, design: .monospaced))
            }
            .padding(10)
            .background(Mode.chill.color)
        }
    }

    struct HakuNodFrame: View {
        let start: Date
        @Environment(\.frameClock) private var clock

        var body: some View {
            let p = (clock ?? start).timeIntervalSince(start) / CompanionView.nodDuration
            var pose = RunnerPose(face: .mid)
            pose.nod(progress: CGFloat(p), still: false)
            return RunnerFigure(mode: .chill, pose: pose)
                .padding(12)
                .background(Mode.chill.color)
        }
    }

    struct KuroNodFrame: View {
        let start: Date
        @Environment(\.frameClock) private var clock

        var body: some View {
            let p = (clock ?? start).timeIntervalSince(start) / CompanionView.nodDuration
            let rest = KuroView.pose(.chill, energy: 50, bedtime: .off, moment: nil, overtimeUntil: nil)
            return KuroFigure(look: .chill, pose: p < 0.1 ? rest.showing(.closed) : rest)
                .offset(y: KuroView.nodDip(p))
                .padding(12)
                .background(KuroLook.chill.color)
        }
    }

    // A sketch of the cross-fade: the view itself animates it with .easeInOut(duration: 0.3).
    struct FadeFrame: View {
        let fade: Bool
        let start: Date
        @Environment(\.frameClock) private var clock

        var body: some View {
            let t = (clock ?? start).timeIntervalSince(start) - 0.1
            let raw = fade ? min(max(t / 0.3, 0), 1) : (t >= 0 ? 1 : 0)
            let k = raw < 0.5 ? 2 * raw * raw : 1 - pow(-2 * raw + 2, 2) / 2
            ZStack {
                Mode.work.color.opacity(1 - k)
                Mode.chill.color.opacity(k)
                RunnerFigure(mode: .work, pose: RunnerPose(face: .mid)).opacity(1 - k)
                RunnerFigure(mode: .chill, pose: RunnerPose(face: .mid)).opacity(k)
            }
            .padding(0)
        }
    }
}
#endif
