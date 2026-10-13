import Foundation
import Testing

// QA S7 (Mike's bug G8): HAKU on the iPhone launch screen was too big. Mike picked the dark launch screen with
// a smaller HAKU (UI log 2026-10-07, PR #233): the icon is 200 pt, about half of a 393 pt wide iPhone. The image
// is the whole icon, glitch bars included, so on the narrowest iPhone (375 pt) it is 53% of the width; HAKU
// alone, without the bars, is about 140 pt there (37%). The test holds the icon to the approved 200 pt.
@Suite struct LaunchImageTests {
    /// The approved width of the launch icon, in points.
    static let approvedWidth = 200

    /// The repository's root folder, five levels above this file.
    static let root = (0..<5).reduce(URL(fileURLWithPath: #filePath)) { url, _ in url.deletingLastPathComponent() }
    /// The launch icon's folder in the iOS app.
    static let folder = root.appendingPathComponent("Apps/iOS/Launch.xcassets/LaunchIcon.imageset")

    @Test(arguments: [2, 3])
    func theLaunchIconKeepsTheApprovedSize(_ scale: Int) throws {
        let url = Self.folder.appendingPathComponent("launch-icon@\(scale)x.png")
        let data = try Data(contentsOf: url)
        let (width, height) = try #require(Self.pixelSize(ofPNG: data))
        #expect(width == height)
        #expect(width / scale == Self.approvedWidth, "@\(scale)x is \(width) px")
    }

    /// The width and height in pixels from a PNG's header, or nil when `data` isn't a PNG.
    static func pixelSize(ofPNG data: Data) -> (Int, Int)? {
        let bytes = [UInt8](data)
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard bytes.count >= 24, Array(bytes[0..<8]) == signature else { return nil }
        guard bytes[12..<16].elementsEqual(Array("IHDR".utf8)) else { return nil }
        let number = { (start: Int) in bytes[start..<(start + 4)].reduce(0) { $0 << 8 | Int($1) } }
        return (number(16), number(20))
    }
}
