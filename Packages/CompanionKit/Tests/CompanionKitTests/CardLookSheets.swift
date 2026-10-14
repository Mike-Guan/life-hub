#if os(macOS)
import Foundation
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// Preview only (preview/haku-card-looks): the base outfits on the fourth slot. Never merged.
extension FrameSheets {
    @Test func hakuCardLooks() throws {
        let cards: [(String, IdentityKind?)] = [
            ("拳击（不变）", nil), ("运动 · 网球", .tennis), ("户外", .outdoor), ("创作 · 画画", .art),
        ]
        var rows = cards.map { name, card in
            Row(label: "手机 · \(name)", start: Self.base) {
                AnyView(CompanionView(mode: .boxing, energy: 50, identity: card))
            }
        }
        rows += cards.map { name, card in
            Row(label: "手表 · \(name)", start: Self.base) {
                AnyView(CompanionView(mode: .boxing, energy: 50, identity: card, style: .watch))
            }
        }
        try write("card-looks", rows, frames: 6, step: 0.4)
    }
}
#endif
