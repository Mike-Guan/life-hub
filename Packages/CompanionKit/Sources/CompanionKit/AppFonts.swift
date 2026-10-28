import CoreText
import Foundation

/// The fonts the iOS app ships in its bundle, for Japanese text.
public enum AppFonts {
    /// PostScript name of the Japanese face for semibold and bold text.
    public static let japaneseBold = "ZenMaruGothic-Bold"
    /// PostScript name of the Japanese face for heavy and black text.
    public static let japaneseBlack = "ZenMaruGothic-Black"

    static let names = [japaneseBold, japaneseBlack]

    /// Registers the bundled fonts for the running process: the app, or an extension inside it.
    /// - Returns: The names of the fonts that could not be registered.
    @discardableResult
    public static func register() -> [String] {
        // The fonts ship once, in the app. An extension sits at <App>.app/PlugIns/<Extension>.appex.
        var folder = Bundle.main.bundleURL
        if folder.pathExtension == "appex" { folder = folder.deletingLastPathComponent().deletingLastPathComponent() }
        return register(in: folder)
    }

    /// Registers the bundled fonts found in `folder` for the running process.
    /// - Parameter folder: The folder holding `<name>.ttf` for each font.
    /// - Returns: The names of the fonts that could not be registered. A font already registered counts as registered.
    static func register(in folder: URL) -> [String] {
        names.filter { name in
            var error: Unmanaged<CFError>?
            let url = folder.appending(path: "\(name).ttf") as CFURL
            if CTFontManagerRegisterFontsForURL(url, .process, &error) { return false }
            guard let error = error?.takeRetainedValue() else { return true }
            return CFErrorGetCode(error) != CTFontManagerError.alreadyRegistered.rawValue
        }
    }
}
