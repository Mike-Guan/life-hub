#if os(macOS)
import SwiftUI
import Testing

@testable import CompanionKit

// QA S5 (00 团队/QA/Mike 找过的错 自动测试对照.md): the mode chip sits left of the system clock in the
// watch's top row. The watch app has no test target, so this measures the same text, font and padding as
// `ModeChip` in Apps/Watch/LifeHubWatchApp.swift; keep the two in step.
@MainActor
@Suite struct WatchChipFitTests {
    /// The 41 mm watch's screen width in points, the smallest size the spec checks.
    static let screenWidth: CGFloat = 176
    /// The chip's leading padding in `LifeHubWatchApp`.
    static let leading: CGFloat = 14

    func width(_ view: some View) throws -> CGFloat {
        let renderer = ImageRenderer(content: view.fixedSize())
        renderer.scale = 1
        return CGFloat(try #require(renderer.cgImage).width)
    }

    func chipWidth(_ name: String) throws -> CGFloat {
        try width(
            Text(name)
                .font(Toy.body(12, weight: .heavy))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .overlay(Capsule().stroke(Toy.ink, lineWidth: 2))
        )
    }

    // The watch draws its clock in the system font; "10:09" is about as wide as times get.
    // The macOS stand-in is the system font at the watch clock's size.
    func clockWidth() throws -> CGFloat {
        try width(Text("10:09").font(.system(size: 16, weight: .semibold)))
    }

    // The two widest names `ModeCards.nameWidth` allows, and the chip's text with no mode.
    @Test(arguments: ["一二三四", "WWWWWWWW", "还没有模式"])
    func theWidestNameLeavesRoomForTheClock(_ name: String) throws {
        let chip = try chipWidth(name)
        let room = Self.screenWidth - (try clockWidth()) - 4
        print("watch chip \(name): \(Self.leading + chip) pt of \(room) pt")
        #expect(Self.leading + chip < room)
    }
}
#endif
