import CoreText
import Foundation
import Testing

@testable import CompanionKit

@Suite struct AppFontsTests {
    @Test func reportsFontsMissingFromTheFolder() {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        #expect(AppFonts.register(in: folder) == [AppFonts.japaneseBold, AppFonts.japaneseBlack])
    }

    @Test func registersTheFontsTheAppShips() {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fonts = root.appending(path: "Apps/iOS/Fonts")
        #expect(AppFonts.register(in: fonts).isEmpty)
        // A second call finds them already registered.
        #expect(AppFonts.register(in: fonts).isEmpty)
        for name in AppFonts.names {
            #expect(CTFontCopyPostScriptName(CTFontCreateWithName(name as CFString, 15, nil)) as String == name)
        }
    }
}
