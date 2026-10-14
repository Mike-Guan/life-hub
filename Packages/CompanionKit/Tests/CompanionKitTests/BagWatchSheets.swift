#if os(macOS)
import Foundation
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// Preview only (preview/haku-gym-bag): the heavy bag on the watch. Never merged.
extension FrameSheets {
    @Test func hakuBagWatch() throws {
        let rows = [
            Row(label: "watch 46 mm · boxingAtGym", start: Self.base) {
                AnyView(CompanionView(mode: .boxing, energy: 50, activity: .boxingAtGym, style: .watch))
            },
            Row(label: "phone · boxingAtGym", start: Self.base) {
                AnyView(CompanionView(mode: .boxing, energy: 50, activity: .boxingAtGym))
            },
        ]
        try write("bag-watch-46mm", rows, size: CGSize(width: 208, height: 248))
    }
}
#endif
