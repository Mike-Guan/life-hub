#if os(macOS)
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// Scratch sheet for the UI review of #546: her line card at iPhone SE width in each language.
extension FrameSheets {
    @Test func kuroLineCard() throws {
        let fonts = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../../Apps/iOS/Fonts").standardized
        #expect(AppFonts.register(in: fonts).isEmpty)
        try Self.compileCatalogs()
        defer { Languages.choice = .chinese }
        var cells: [(String, CGImage)] = []
        let cases: [(String, Languages.Choice, Mode?)] = [
            ("zh arrive", .chinese, nil), ("ja arrive", .japanese, nil), ("en arrive", .english, nil),
            ("zh money (longest)", .chinese, .money), ("ja money (longest)", .japanese, .money),
            ("en money (longest)", .english, .money),
        ]
        for (label, choice, mode) in cases {
            Languages.choice = choice
            var snapshot = HomeSnapshot.preview()
            snapshot.persona = .kuro
            snapshot.cards = ModeCards(identity: .tennis)
            let model = HomeModel(snapshot: snapshot, night: false, now: HomeModel.start)
            if let mode { model.switchMode(mode) }
            let page = HakuHomeView(
                snapshot: snapshot, onSwitch: { _ in }, onShop: nil, onWardrobe: nil, onSave: { _ in },
                onExit: {})
            let card = page.lineCard(model).frame(width: 343).padding(.horizontal, 16).padding(.vertical, 8)
                .frame(width: 375).background(Toy.paper)
            let renderer = ImageRenderer(content: card)
            renderer.scale = 2
            cells.append((label, try #require(renderer.cgImage)))
        }
        let sheet = VStack(alignment: .leading, spacing: 6) {
            ForEach(cells.indices, id: \.self) { i in
                Text(verbatim: cells[i].0).font(.system(size: 13, weight: .bold))
                Image(decorative: cells[i].1, scale: 1)
            }
        }
        .padding(10)
        .background(Color.white)
        try save(sheet, as: "kuro-line-card-se", scale: 1)
    }

    // `swift test` copies the String Catalogs without compiling them; this writes the `.lproj` tables an app
    // build makes into the built resource bundles.
    private static func compileCatalogs() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../../..")
            .standardized
        let built = Bundle(for: KuroHomeNode.self).bundleURL.deletingLastPathComponent()
        for (package, tables) in [
            ("CompanionKit", ["Kuro", "Haku", "Localizable"]), ("HubCore", ["Kuro", "Haku", "Localizable", "Short"]),
        ] {
            let bundle = built.appending(path: "\(package)_\(package).bundle")
            let resources = FileManager.default.fileExists(atPath: bundle.appending(path: "Contents").path)
                ? bundle.appending(path: "Contents/Resources") : bundle
            for table in tables {
                let source = root.appending(path: "\(package)/Sources/\(package)/Resources/\(table).xcstrings")
                let data = try Data(contentsOf: source)
                let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
                let strings = try #require(json["strings"] as? [String: Any])
                for code in ["ja", "en"] {
                    var out: [String: String] = [:]
                    for (key, value) in strings {
                        let l = (value as? [String: Any])?["localizations"] as? [String: Any]
                        let unit = (l?[code] as? [String: Any])?["stringUnit"] as? [String: Any]
                        if let v = unit?["value"] as? String { out[key] = v }
                    }
                    let folder = resources.appending(path: "\(code).lproj")
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let plist = try PropertyListSerialization.data(fromPropertyList: out, format: .xml, options: 0)
                    try plist.write(to: folder.appending(path: "\(table).strings"))
                }
            }
            print("catalogs written to \(resources.path)")
        }
    }
}
#endif
