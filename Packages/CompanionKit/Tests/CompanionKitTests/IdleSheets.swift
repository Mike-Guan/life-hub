#if os(macOS)
import Foundation
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// Preview only (batch 1, idle): not for main.
extension FrameSheets {
    typealias Tick = (label: String, color: Color, on: (RunnerPose) -> Bool)

    static let idleTicks: [Mode: [Tick]] = [
        .work: [
            ("眨眼", .black, { $0.squeeze < 0.5 }),
            ("点头停一拍", .gray, { _ in false }),
            ("大点头+推耳机", .purple, { $0.headsetOff > 0.01 || $0.headDy > 2 }),
            ("瞟手机", .blue, { $0.phoneGlance }),
            ("眼睛飘", .orange, { abs($0.eyesDx) > 1 }),
        ],
        .chill: [
            ("眨眼(闭眼笑挤)", .black, { $0.squeeze < 0.5 }),
            ("喝一口", .teal, { $0.canAngle < -10 && $0.canOffset.height != -10 }),
            ("空罐", .red, { $0.canOffset.height == -10 }),
            ("抓头", .green, { $0.scratch >= 0 || $0.tuft > 0.05 }),
            ("眼睛飘", .orange, { abs($0.eyesDx) > 1 && $0.canOffset.height != -10 }),
        ],
        .boxing: [
            ("眨眼", .black, { $0.squeeze < 0.5 }),
            ("甩手腕+整理头带", .pink, { $0.gloveL.height == 8 || $0.gloveR.height < -20 }),
            ("眼睛飘", .orange, { abs($0.eyesDx) > 1 && $0.gloveR.height > -20 }),
        ],
    ]

    /// Ten minutes of idle events per mode, one tick per sampled 0.05 s that shows the event.
    @Test func idleTimeline() throws {
        let start = Self.start(for: nil).timeIntervalSinceReferenceDate
        let width: CGFloat = 1200
        let sheet = VStack(alignment: .leading, spacing: 6) {
            Text("idle-timeline · 10 分钟 · 每像素 0.5 s · 每 60 s 一条竖线")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
            ForEach([Mode.work, .chill, .boxing], id: \.self) { mode in
                let ticks = Self.idleTicks[mode] ?? []
                let poses = (0..<12_000).map {
                    RunnerPose(mode: mode, time: start + Double($0) * 0.05, face: .mid, react: 0)
                }
                ForEach(ticks.indices, id: \.self) { index in
                    let tick = ticks[index]
                    let nods = mode == .work && tick.label == "点头停一拍"
                    HStack(spacing: 8) {
                        Text("\(mode.rawValue) · \(tick.label)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .frame(width: 190, alignment: .leading)
                        Canvas { context, size in
                            for minute in 0...10 {
                                let x = CGFloat(minute) * width / 10
                                context.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(.gray.opacity(0.4)))
                            }
                            for step in 0..<12_000 {
                                let on: Bool
                                if nods {
                                    let t = start + Double(step) * 0.05
                                    on = step % 10 == 0 && (0..<10).allSatisfy {
                                        IdleClock.nod(at: t + Double($0) * 0.05, period: 0.5, seed: RunnerPose.seed) == 0
                                    }
                                } else {
                                    on = tick.on(poses[step])
                                }
                                guard on else { continue }
                                let x = CGFloat(step) * width / 12_000
                                context.fill(Path(CGRect(x: x, y: 2, width: 1.2, height: size.height - 4)), with: .color(tick.color))
                            }
                        }
                        .frame(width: width, height: 18)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        try save(sheet, as: "idle-0-timeline", scale: 2)
    }

    /// The first start of a pool beat of `kind` after `date`.
    static func beatStart(
        after date: Date, kind: Int, lengths: [TimeInterval], every: TimeInterval = 14, spread: TimeInterval = 3,
        seed: UInt64 = RunnerPose.seed
    ) -> Date {
        let t0 = date.timeIntervalSinceReferenceDate
        for step in 0..<60_000 {
            let t = t0 + Double(step) * 0.01
            if let beat = IdleClock.beat(at: t, every: every, spread: spread, lengths: lengths, seed: seed),
                beat.kind == kind, beat.phase < 0.01
            {
                return Date(timeIntervalSinceReferenceDate: t)
            }
        }
        return date
    }

    @Test func idleBeats() throws {
        let home = Self.start(for: nil)
        let rows = [
            ("work · 大点头+推耳机", Mode.work, Self.beatStart(after: Self.base, kind: 0, lengths: RunnerPose.workBeats)),
            ("work · 瞟手机", .work, Self.beatStart(after: Self.base, kind: 1, lengths: RunnerPose.workBeats)),
            ("chill · 空罐", .chill, Self.beatStart(after: home, kind: 0, lengths: RunnerPose.chillBeats)),
            ("chill · 抓头", .chill, Self.beatStart(after: home, kind: 1, lengths: RunnerPose.chillBeats)),
            ("boxing · 甩手腕", .boxing, Self.beatStart(after: Self.base, kind: 0, lengths: [3.5], every: 24, spread: 6)),
        ].map { label, mode, start in
            Row(label: label, start: start - 0.25) { AnyView(CompanionView(mode: mode, energy: 50)) }
        }
        try write("idle-1-beats", rows, frames: 16, step: 0.25)
        let blinkAt = { (from: Date, double: Bool) -> Date in
            var t = from.timeIntervalSinceReferenceDate
            while true {
                let shut = RunnerPose.blink(at: t) < 0.5
                let second = RunnerPose.blink(at: t + IdleClock.doubleBlinkGap) < 0.5
                if shut, !double || second { return Date(timeIntervalSinceReferenceDate: t - 0.08) }
                t += 0.01
            }
        }
        let blinks = [
            ("work · 眨眼", Mode.work, blinkAt(Self.base, false)),
            ("work · 双眨", .work, blinkAt(Self.base, true)),
            ("chill · 闭眼笑挤一下", .chill, blinkAt(home, false)),
        ].map { label, mode, start in
            Row(label: label, start: start) { AnyView(CompanionView(mode: mode, energy: 50)) }
        }
        try write("idle-2-blinks", blinks, size: CGSize(width: 240, height: 320), frames: 12, step: 0.04)
        let breaths = [CompanionMoment.slacking, .packingUp].map { moment in
            Row(label: "work · moment \(moment)", start: Self.base) {
                AnyView(CompanionView(mode: .work, energy: 50, moment: moment))
            }
        }
        try write("idle-3-breath", breaths, frames: 10, step: 0.4)
    }
}
#endif
