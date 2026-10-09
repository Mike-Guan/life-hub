#if os(macOS)
import Foundation
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// Preview only (Mike 2026-10-09: overlap candidates from the sweep): not for main.
private struct HakuAt: View {
    let mode: Mode
    let build: (TimeInterval) -> RunnerPose
    let room: RunnerPart?
    let traces: Set<CompanionTrace>
    @Environment(\.frameClock) private var clock

    var body: some View {
        let t = (clock ?? FrameSheets.base).timeIntervalSince(FrameSheets.base)
        var outfit = Outfit()
        outfit.room = room
        return ZStack {
            Rectangle().fill(Color(red: 0.42, green: 0.6, blue: 0.45))
            RunnerFigure(mode: mode, pose: build(t).wearing(outfit).leaving(traces)).padding(14)
        }
    }
}

extension FrameSheets {
    @Test func overlapCandidates() throws {
        func row(
            _ label: String, _ mode: Mode, room: RunnerPart?, traces: Set<CompanionTrace>,
            _ build: @escaping (TimeInterval) -> RunnerPose
        ) -> Row {
            Row(label: label, start: Self.base) {
                AnyView(HakuAt(mode: mode, build: build, room: room, traces: traces))
            }
        }
        let shoes: Set<CompanionTrace> = [.runningShoes]
        let all: Set<CompanionTrace> = [.pcGlow, .bandage, .runningShoes]
        let rows = [
            row("R1 home · pc + bandage + plant", .chill, room: .roomPlant, traces: all) {
                RunnerPose(mode: .chill, time: $0, face: .mid, react: 0)
            },
            row("R2 home · scratch beat", .chill, room: nil, traces: all) {
                RunnerPose(mode: .chill, time: 33.6 + $0, face: .mid, react: 0)
            },
            row("R3 home · headphones prop", .chill, room: nil, traces: all) {
                var pose = RunnerPose(mode: .chill, time: $0, face: .mid, react: 0)
                pose.dailyProp = .headphones
                return pose
            },
            row("R4 swim cheer · pc", .chill, room: nil, traces: all) {
                var pose = RunnerPose(mode: .chill, time: $0, face: .mid, react: 0)
                pose.celebrate(.swimming, progress: CGFloat($0 / 4))
                return pose
            },
            row("R5 work · bandage", .work, room: nil, traces: [.bandage]) {
                RunnerPose(mode: .work, time: $0, face: .mid, react: 0)
            },
            row("R6 boxing · bandage", .boxing, room: nil, traces: [.bandage]) {
                RunnerPose(mode: .boxing, time: $0, face: .mid, react: 0)
            },
            row("R7 money · bandage", .money, room: nil, traces: [.bandage]) {
                RunnerPose(mode: .money, time: $0, face: .mid, react: 0)
            },
            row("R8 nap · pc hidden", .chill, room: .roomPlant, traces: all) {
                RunnerPose(mode: .chill, time: $0, face: .mid, life: .nap, react: 0)
            },
        ]
        try write("overlap-r2", rows, frames: 8, step: 0.5)
    }
}
#endif
