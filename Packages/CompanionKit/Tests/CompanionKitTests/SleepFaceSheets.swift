#if os(macOS)
import Foundation
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// Preview only (preview/sleep-faces): last night's sleep face per mode and energy, for UI 审核. Never merged.
extension FrameSheets {
    static let sleepEnergies: [(String, Double?)] = [("累 20", 20), ("中 50", 50), ("满 85", 85), ("没戴表", nil)]

    @Test func hakuSleepFacesHome() throws {
        var rows: [Row] = []
        for mode in Mode.allCases {
            for (name, energy) in Self.sleepEnergies {
                rows.append(
                    Row(label: "主页 \(mode.rawValue) · \(name)", start: Self.base) {
                        AnyView(CompanionView(mode: mode, energy: energy))
                    })
            }
        }
        try write("sleep-1-home", rows, frames: 6, step: 1.0)
    }

    @Test func hakuSleepFacesWatch() throws {
        var rows: [Row] = []
        for mode in Mode.allCases {
            for (name, energy) in Self.sleepEnergies {
                rows.append(
                    Row(label: "手表 \(mode.rawValue) · \(name)", start: Self.base) {
                        AnyView(CompanionView(mode: mode, energy: energy, style: .watch).clipped())
                    })
            }
        }
        try write("sleep-2-watch", rows, size: CGSize(width: 198, height: 242), frames: 6, step: 1.0)
    }
}
#endif
