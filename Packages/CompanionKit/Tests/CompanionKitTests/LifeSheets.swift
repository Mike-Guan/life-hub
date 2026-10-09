#if os(macOS)
import Foundation
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// Preview only (batch 1, HAKU-04 part): not for main.
extension FrameSheets {
    @Test func lifeTurns() throws {
        var rows: [Row] = []
        var slot = (Self.base.timeIntervalSinceReferenceDate / IdleLife.slotLength).rounded(.up) * IdleLife.slotLength
        while rows.count < 4 {
            let date = Date(timeIntervalSinceReferenceDate: slot)
            let before = IdleLife.at(date - 1)
            let after = IdleLife.at(date)
            if before != after {
                let label = "\(before.map { "\($0)" } ?? "plain") → \(after.map { "\($0)" } ?? "plain")"
                rows.append(Row(label: label, start: date - 0.2) { AnyView(CompanionView(mode: .chill, energy: 50)) })
            }
            slot += IdleLife.slotLength
        }
        try write("life-turns", rows, frames: 10, step: 0.1)
    }
}
#endif
