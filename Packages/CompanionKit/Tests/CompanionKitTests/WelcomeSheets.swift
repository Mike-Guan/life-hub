#if os(macOS)
import Foundation
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// Preview only (batch 1, HAKU-17): not for main.
private struct WelcomeAt: View {
    let scene: WelcomeScene
    let mode: Mode
    @Environment(\.frameClock) private var clock

    var body: some View {
        let t = CGFloat((clock ?? FrameSheets.base).timeIntervalSince(FrameSheets.base))
        ZStack {
            Rectangle().fill(mode == .work ? Color(red: 0.5, green: 0.72, blue: 1) : Color(red: 0.55, green: 0.85, blue: 0.6))
            RunnerFigure(mode: mode, pose: RunnerPose.welcome(scene, time: t, open: nil, face: .mid, mode: mode))
                .padding(14)
        }
    }
}

extension FrameSheets {
    @Test func welcomeByPlace() throws {
        var rows: [Row] = []
        for scene in [WelcomeScene.quiet] {
            for mode in [Mode.work] {
                rows.append(
                    Row(label: "\(scene) · \(mode.rawValue)", start: Self.base) {
                        AnyView(WelcomeAt(scene: scene, mode: mode))
                    })
            }
        }
        try write("welcome-place-r2", rows, frames: 14, step: 0.4)
    }
}
#endif
