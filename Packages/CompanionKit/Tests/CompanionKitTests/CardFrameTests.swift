#if os(macOS)
import CoreGraphics
import Foundation
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// QA S1 (Mike's bug G1): KURO's home card was white with half a frame. Each character's card is drawn 390 pt
// wide like the home screen and checked for the black frame on every side, the hard shadow and a colored fill.
@Suite @MainActor struct CardFrameTests {
    // A Tuesday at 10:00 UTC, as in the frame sheets.
    static let base = Date(timeIntervalSinceReferenceDate: 812_973_600)
    static let gutter: CGFloat = 16
    static let card = CGRect(x: 16, y: 16, width: 358, height: 340)
    static let scale: CGFloat = 2

    @Test(arguments: Persona.allCases, Mode.allCases)
    func theHomeCardHasItsFrameShadowAndColor(_ persona: Persona, _ mode: Mode) throws {
        let renderer = ImageRenderer(content: Self.home(persona, mode))
        renderer.scale = Self.scale
        let image = try #require(renderer.cgImage)
        let pixels = try #require(CardPixels(image, scale: Self.scale))
        let card = Self.card
        let label = "\(persona) \(mode)"
        // Each corner and the middle of each side, from a spot of the fill 14 pt inside towards the edge.
        let probes: [(CGPoint, CGVector)] = [
            (CGPoint(x: card.minX + 14, y: card.minY + 14), CGVector(dx: -0.5, dy: -0.5)),
            (CGPoint(x: card.maxX - 14, y: card.minY + 14), CGVector(dx: 0.5, dy: -0.5)),
            (CGPoint(x: card.minX + 14, y: card.maxY - 14), CGVector(dx: -0.5, dy: 0.5)),
            (CGPoint(x: card.maxX - 14, y: card.maxY - 14), CGVector(dx: 0.5, dy: 0.5)),
            (CGPoint(x: card.minX + 14, y: card.midY), CGVector(dx: -0.5, dy: 0)),
            (CGPoint(x: card.maxX - 14, y: card.midY), CGVector(dx: 0.5, dy: 0)),
            (CGPoint(x: card.minX + 30, y: card.minY + 14), CGVector(dx: 0, dy: -0.5)),
            (CGPoint(x: card.minX + 30, y: card.maxY - 14), CGVector(dx: 0, dy: 0.5)),
        ]
        for (start, step) in probes {
            let edge = try #require(pixels.edge(from: start, step: step), "\(label) no edge from \(start)")
            #expect(edge < 0.15, "\(label) edge from \(start) is not black: \(edge)")
        }
        // The hard shadow below and to the right, past the frame.
        #expect(pixels.luminance(at: CGPoint(x: card.maxX + 3.5, y: card.midY)) < 0.15, "\(label) right shadow")
        #expect(pixels.luminance(at: CGPoint(x: card.minX + 30, y: card.maxY + 3.5)) < 0.15, "\(label) bottom shadow")
        // The middle row is the card's color, never white. The character stands in the middle, so only the
        // fill on either side of it is read.
        for left in [card.minX + 6, card.maxX - 40] {
            for x in stride(from: left, to: left + 34, by: 0.5) {
                #expect(!pixels.isWhite(at: CGPoint(x: x, y: card.midY)), "\(label) white at \(x)")
            }
        }
    }

    /// The character for `persona` in `mode` in a home card on the app's paper background, 390 pt wide.
    static func home(_ persona: Persona, _ mode: Mode) -> some View {
        figure(persona, mode)
            .environment(\.frameClock, base)
            .environment(\.scenePhase, .active)
            .frame(width: card.width, height: card.height)
            .toyCard()
            .padding(gutter)
            .background(Toy.paper)
    }

    @ViewBuilder static func figure(_ persona: Persona, _ mode: Mode) -> some View {
        if persona == .kuro {
            KuroView(look: KuroLook(mode: mode), energy: 50)
        } else {
            CompanionView(mode: mode, energy: 50)
        }
    }
}

/// The sRGB pixels of a rendered image, read in points from the top left.
private struct CardPixels {
    let width: Int
    let height: Int
    let scale: CGFloat
    let bytes: [UInt8]

    init?(_ image: CGImage, scale: CGFloat) {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let (width, height) = (image.width, image.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        self.width = width
        self.height = height
        self.scale = scale
        self.bytes = bytes
    }

    /// The red, green and blue values (0-255) at `point`, or nil outside the image.
    func rgb(at point: CGPoint) -> [Int]? {
        let x = Int(point.x * scale)
        let y = Int(point.y * scale)
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let index = (y * width + x) * 4
        return (0..<3).map { Int(bytes[index + $0]) }
    }

    /// The relative luminance (0-1) at `point`, or 1 outside the image.
    func luminance(at point: CGPoint) -> Double {
        guard let rgb = rgb(at: point) else { return 1 }
        return (0.2126 * Double(rgb[0]) + 0.7152 * Double(rgb[1]) + 0.0722 * Double(rgb[2])) / 255
    }

    /// Whether the pixel at `point` is pure white.
    func isWhite(at point: CGPoint) -> Bool {
        rgb(at: point) == [255, 255, 255]
    }

    /// The darkest luminance in the 2 pt after the first pixel that differs from the one at `start`, walking by
    /// `step` points for up to 24 pt, or nil when nothing differs.
    func edge(from start: CGPoint, step: CGVector) -> Double? {
        guard let fill = rgb(at: start) else { return nil }
        let point = { (index: Int) in
            CGPoint(x: start.x + step.dx * CGFloat(index), y: start.y + step.dy * CGFloat(index))
        }
        let steps = Int(24 / max(abs(step.dx), abs(step.dy)))
        let first = (1...steps).first { index in
            guard let rgb = rgb(at: point(index)) else { return false }
            return zip(rgb, fill).contains { abs($0 - $1) > 40 }
        }
        guard let first else { return nil }
        let window = Int(2 / max(abs(step.dx), abs(step.dy)))
        return (first...(first + window)).map { luminance(at: point($0)) }.min()
    }
}
#endif
