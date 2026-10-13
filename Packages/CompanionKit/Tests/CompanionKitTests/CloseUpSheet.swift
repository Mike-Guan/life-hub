#if os(macOS)
import Foundation
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// Preview only (preview/kuro-closeup): the watch close-up next to the normal frame, for UI 审核. Never merged.
extension FrameSheets {
    @Test func watchCloseUps() throws {
        var rows: [Row] = []
        for look in KuroLook.allCases {
            rows.append(
                Row(label: "kuro \(look) · 平时", start: Self.base) {
                    AnyView(KuroView(look: look, energy: 50, style: .watch))
                })
            rows.append(
                Row(label: "kuro \(look) · 长按特写", start: Self.base) {
                    AnyView(
                        KuroView(look: look, energy: 50, style: .watch)
                            .scaleEffect(1.8, anchor: CompanionView.closeUpAnchor(.watch)).clipped())
                })
        }
        for mode in Mode.allCases {
            rows.append(
                Row(label: "haku \(mode.rawValue) · 长按特写", start: Self.base) {
                    AnyView(
                        CompanionView(mode: mode, energy: 50, style: .watch)
                            .scaleEffect(1.8, anchor: CompanionView.closeUpAnchor(.watch)).clipped())
                })
        }
        try write("kuro-watch-closeup", rows, size: CGSize(width: 198, height: 242), frames: 3)
    }
}
#endif
