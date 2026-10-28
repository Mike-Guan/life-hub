#if os(iOS) || os(macOS)
import HubCore
import SpriteKit
import SwiftUI

// UI 二组 首页家窗口 v1 (家 功能范围 A 档: the home screen's way into the home shows what the character is doing
// there). 动态 only when the picture changes: the old still fades into the new one. The rest of the time it stays
// still, since the home screen's own character already moves above it.
/// The home seen through a small window: a still of the real room around the character, where she is now, with a
/// line saying where that is. For the home screen.
public struct HomeWindow: View {
    let snapshot: HomeSnapshot
    let now: Date
    @State private var drawn: Drawn?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - snapshot: the home page's snapshot, as the app builds it when the home opens.
    ///   - now: the time, for day or night.
    public init(snapshot: HomeSnapshot, now: Date) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        GeometryReader { geo in
            if let drawn {
                let origin = Self.origin(figure: drawn.figure, room: drawn.size, window: geo.size)
                Image(decorative: drawn.image, scale: 2)
                    .offset(x: -origin.x, y: -origin.y)
                    .id(drawn.revision)
                    .transition(.opacity)
            }
        }
        .clipped()
        .background(Toy.paper)
        .overlay(alignment: .bottomLeading) {
            if let drawn {
                Text(drawn.line)
                    .font(Toy.body(14, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(Toy.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Toy.card))
                    .overlay(Capsule().stroke(Toy.ink, lineWidth: 2))
                    .padding(10)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: drawn?.revision)
        .task(id: key) { draw(key) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(drawn?.line ?? "")
    }

    /// What changes the picture: not today's timeline or the cans, which the room doesn't show.
    private var key: Key {
        var shown = snapshot
        shown.today = []
        shown.cans = 0
        return Key(snapshot: shown, night: HomeModel.isNight(at: now))
    }

    private func draw(_ key: Key) {
        let model = HomeModel(snapshot: key.snapshot, night: key.night)
        let scene = HomeScene(model: model)
        scene.sync(animated: false)
        scene.settle()
        scene.pose(at: 1.3)
        guard let image = scene.still(scale: 2) else { return }
        // Scene points run up from the bottom; the image's run down from the top.
        let frame = scene.haku.calculateAccumulatedFrame()
        let figure = CGRect(
            x: frame.minX, y: scene.size.height - frame.maxY, width: frame.width, height: frame.height)
        drawn = Drawn(
            revision: (drawn?.revision ?? 0) + 1, image: image, figure: figure, size: scene.size,
            line: Self.line(model.spot, persona: key.snapshot.persona))
    }

    /// The top left corner of the window in the room, the character in its middle, kept inside the room.
    static func origin(figure: CGRect, room: CGSize, window: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(figure.midX - window.width / 2, 0), max(room.width - window.width, 0)),
            y: min(max(figure.midY - window.height / 2, 0), max(room.height - window.height, 0)))
    }

    /// Where the character is, in words: only the place, nothing she can't be seen doing.
    static func line(_ spot: HomeSpot, persona: Persona) -> String {
        let format =
            switch spot {
            case .work, .side: "%@ 在书桌前"
            case .sofa: "%@ 在沙发上"
            case .rest: "%@ 在床上"
            case .box, .shadowbox, .bench, .practice: "%@ 在活动身体"
            case .idle, .wardrobe, .shop, .window: "%@ 在屋里"
            }
        return String(format: format.localized, persona.title)
    }

    private struct Key: Equatable {
        var snapshot: HomeSnapshot
        var night: Bool
    }

    private struct Drawn {
        let revision: Int
        let image: CGImage
        /// The character, in the room's points from its top left.
        let figure: CGRect
        let size: CGSize
        let line: String
    }
}
#endif
