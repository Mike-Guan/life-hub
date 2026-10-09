#if os(macOS)
import Foundation
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// Preview only (Mike's bug: the monitor showed behind HAKU's tilted head): not for main.
private struct PillowAt: View {
    let bedtime: Bool
    let traces: Set<CompanionTrace>
    @Environment(\.frameClock) private var clock

    var body: some View {
        let t = (clock ?? FrameSheets.base).timeIntervalSince(FrameSheets.base)
        let pose =
            bedtime
            ? RunnerPose.bedtime(time: t, goodnight: 1, liesDown: true)
            : RunnerPose(mode: .chill, time: t, face: .mid, life: .nap, react: 0)
        ZStack {
            Rectangle().fill(Color(red: 0.42, green: 0.6, blue: 0.45))
            RunnerFigure(mode: .chill, pose: pose.leaving(traces)).padding(14)
        }
    }
}

extension FrameSheets {
    @Test func pcPillow() throws {
        let rows = [
            Row(label: "nap · pcGlow + bandage", start: Self.base) {
                AnyView(PillowAt(bedtime: false, traces: [.pcGlow, .bandage]))
            },
            Row(label: "bedtime lies down · pcGlow", start: Self.base) {
                AnyView(PillowAt(bedtime: true, traces: [.pcGlow]))
            },
            Row(label: "plain home · pcGlow", start: Self.base) {
                AnyView(ZStack {
                    Rectangle().fill(Color(red: 0.42, green: 0.6, blue: 0.45))
                    RunnerFigure(mode: .chill, pose: RunnerPose().leaving([.pcGlow])).padding(14)
                })
            },
        ]
        try write("pc-pillow", rows, frames: 6, step: 1)
    }
}
#endif
