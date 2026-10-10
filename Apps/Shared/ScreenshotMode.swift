import HubCore
import SwiftUI

// Used by .github/workflows/screenshots.yml to draw the README images. Debug builds only.
/// Launch argument `-screenshot-mode <mode>` shows the home screen with fixed, in-memory data.
/// `-screenshot-persona <persona>` picks the character, HAKU by default.
/// `-screenshot-wearing <ids>` dresses her in shop items, given as comma-separated ids.
/// `-screenshot-memory <full|empty>` shows the memory page instead (iOS).
enum ScreenshotMode {
    static var mode: Mode? {
        value(after: "-screenshot-mode").flatMap(Mode.init(rawValue:))
    }

    /// Whether the memory page has records to show, `nil` when it isn't being drawn.
    static var memory: Bool? {
        value(after: "-screenshot-memory").map { $0 == "full" }
    }

    /// Whether any screenshot is being drawn.
    static var isOn: Bool { mode != nil || memory != nil }

    static var persona: Persona {
        value(after: "-screenshot-persona").flatMap(Persona.init(rawValue:)) ?? .haku
    }

    static var wardrobe: Wardrobe {
        var wardrobe = Wardrobe()
        for id in value(after: "-screenshot-wearing")?.split(separator: ",") ?? [] {
            if let item = ShopItem.item(String(id)) { wardrobe.equip(item) }
        }
        return wardrobe
    }

    private static func value(after flag: String) -> String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
        #else
        nil
        #endif
    }
}

/// The home screen in `mode` for `ScreenshotMode.persona`, with no files, permissions or widgets touched.
struct ScreenshotHome: View {
    let mode: Mode
    @State private var store = ModeStore(fileURL: nil, deviceID: "screenshot")
    @State private var energy = EnergyStore(fileURL: nil, deviceID: "screenshot")

    var body: some View {
        // An empty bedtime window, so RUNNER is awake whatever time CI runs.
        HomeView(
            bedtime: BedtimeSchedule(startMinute: 0, endMinute: 0),
            wardrobe: ScreenshotMode.wardrobe,
            persona: ScreenshotMode.persona
        )
        .environment(store)
        .environment(energy)
        .onAppear {
            // A fresh manual change, so the schedule's 2h hold keeps this mode on screen.
            store.switchTo(mode)
            energy.report(.full)
        }
    }
}
