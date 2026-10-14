#if os(macOS)
import Foundation
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// Preview only (preview/bubble-room): the line above HAKU's hair, laid out like CompanionView. Never merged.
extension FrameSheets {
    @Test func bubbleRoom() throws {
        let line = "健身房今天也开着。……我只是说说。"
        let gift = "……给你的。才不是特意挑的。"
        try write(
            "bubble-1-unbox-380", [Row(label: "开箱 380 · A", start: Self.base) { AnyView(Stage(gift, showcase: true)) }],
            size: CGSize(width: 345, height: 380), frames: 1)
        try write(
            "bubble-2-unbox-290", [Row(label: "开箱 290 · A", start: Self.base) { AnyView(Stage(gift, showcase: true)) }],
            size: CGSize(width: 320, height: 290), frames: 1)
        try write(
            "bubble-3-home-340",
            [
                Row(label: "首页 340 · 没说话", start: Self.base) { AnyView(Stage(nil, showcase: false)) },
                Row(label: "首页 340 · C 说话中", start: Self.base) { AnyView(Stage(line, showcase: false)) },
                Row(label: "首页 340 · 减少动态", start: Self.base) { AnyView(Stage(line, showcase: false, still: true)) },
            ],
            size: CGSize(width: 361, height: 340), frames: 1)
    }

    struct Stage: View {
        let line: String?
        let showcase: Bool
        let still: Bool

        init(_ line: String?, showcase: Bool, still: Bool = false) {
            self.line = line
            self.showcase = showcase
            self.still = still
        }

        var body: some View {
            let mode: Mode = .boxing
            var wardrobe = Wardrobe()
            if showcase { wardrobe.equipped[.gloves] = "gloves.gold" }
            let dip = CompanionView.talkDip(style: .standard, showsBubble: true, showcase: showcase, still: still)
            return ZStack {
                Rectangle().fill(mode.color)
                RunnerFigure(mode: mode, pose: RunnerPose(face: .mid).wearing(Outfit(wardrobe)))
                    .padding(
                        .top,
                        CompanionView.figureTop(style: .standard, showsBubble: true, showcase: showcase, still: still)
                    )
                    .padding(.horizontal, 12)
                    .offset(y: line == nil ? 0 : dip)
                if let line {
                    SpeechBubble(text: line)
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .clipped()
        }
    }
}
#endif
