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
        let rows = [
            row("H1 home · plant + shoes", .chill, room: .roomPlant, traces: shoes) {
                RunnerPose(mode: .chill, time: $0, face: .mid, react: 0)
            },
            row("H1 home · bag + shoes + bandage", .chill, room: .roomBag, traces: shoes.union([.bandage])) {
                RunnerPose(mode: .chill, time: $0, face: .mid, react: 0)
            },
            row("H2 collapsed · plant + shoes", .chill, room: .roomPlant, traces: shoes) {
                RunnerPose(mode: .chill, time: $0, face: .mid, moment: .collapsed, react: 0)
            },
            row("H3 prop bag · plant + shoes", .chill, room: .roomPlant, traces: shoes) {
                var pose = RunnerPose(mode: .chill, time: $0, face: .mid, react: 0)
                pose.dailyProp = .bag
                return pose
            },
            row("H4 prop gymBag · bag + shoes", .chill, room: .roomBag, traces: shoes) {
                var pose = RunnerPose(mode: .chill, time: $0, face: .mid, react: 0)
                pose.dailyProp = .gymBag
                return pose
            },
            row("H5 timeToLeave · plant + shoes", .chill, room: .roomPlant, traces: shoes) {
                RunnerPose(mode: .chill, time: $0, face: .mid, moment: .timeToLeave, react: 0)
            },
            row("H6 blanket · plant + shoes", .chill, room: .roomPlant, traces: shoes) {
                RunnerPose(mode: .chill, time: $0, face: .mid, moment: .blanket, react: 0)
            },
            row("H7 nap · pc + plant", .chill, room: .roomPlant, traces: [.pcGlow, .runningShoes]) {
                RunnerPose(mode: .chill, time: $0, face: .mid, life: .nap, react: 0)
            },
            row("H8 runDay · bag + shoes", .chill, room: .roomBag, traces: shoes) {
                RunnerPose(mode: .chill, time: $0, face: .mid, activity: .runDay, react: 0)
            },
            row("H9 flow · desk monitor", .money, room: nil, traces: [.deskMonitor]) {
                RunnerPose(mode: .money, time: 7.5 + $0, face: .mid, moment: .flow, react: 0)
            },
            Row(label: "K1 KURO chill · flower + blanket", start: Self.base) {
                AnyView(
                    ZStack {
                        Rectangle().fill(Color(red: 0.55, green: 0.85, blue: 0.6))
                        KuroFigure(look: .chill, pose: {
                            var pose = KuroPose(look: .chill, energy: 50)
                            pose.items = [.flower, .blanket]
                            return pose
                        }()).padding(14)
                    })
            },
        ]
        try write("overlap-after", rows, frames: 8, step: 0.5)
    }
}
#endif
