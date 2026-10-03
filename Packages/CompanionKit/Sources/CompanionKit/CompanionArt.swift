import HubCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Static RUNNER art per mode, rendered from the v5 SVGs with the background removed.
enum CompanionArt {
    static func image(for mode: Mode) -> Image? {
        guard let url = Bundle.module.url(forResource: mode.artName, withExtension: "png") else { return nil }
        #if canImport(UIKit)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        return Image(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(contentsOf: url) else { return nil }
        return Image(nsImage: image)
        #endif
    }
}
