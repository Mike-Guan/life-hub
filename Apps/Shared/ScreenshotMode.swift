import HubCore
import SwiftUI

// Used by .github/workflows/screenshots.yml to draw the README images. Debug builds only.
/// Launch argument `-screenshot-mode <mode>` shows the home screen with fixed, in-memory data.
/// `-screenshot-persona <persona>` picks the character, HAKU by default.
/// `-screenshot-wearing <ids>` dresses her in shop items, given as comma-separated ids.
enum ScreenshotMode {
    static var mode: Mode? {
        value(after: "-screenshot-mode").flatMap(Mode.init(rawValue:))
    }

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

    /// Today's energy for the screenshot, full when not given.
    static var energy: EnergyLevel {
        value(after: "-screenshot-energy").flatMap(EnergyLevel.init(rawValue:)) ?? .full
    }

    /// Minutes asleep that give `energy` under the standard thresholds.
    static var sleepMinutes: Int {
        switch energy {
        case .low: 5 * 60
        case .okay: 6 * 60 + 40
        case .full: 8 * 60
        }
    }

    /// What the "不对" card shows: `open` for the question, `reply` for the reply after a correction,
    /// `hold` for nothing until a long press.
    static var check: String? {
        value(after: "-screenshot-check")
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
            persona: ScreenshotMode.persona,
            screenshotCheck: ScreenshotMode.check
        )
        .environment(store)
        .environment(energy)
        .onAppear {
            // A fresh manual change, so the schedule's 2h hold keeps this mode on screen.
            store.switchTo(mode)
            // The "不对" card only asks about a guess, so its shots get energy from a night's sleep.
            if ScreenshotMode.check == nil {
                energy.report(ScreenshotMode.energy)
            } else {
                energy.record(.sleep(minutes: ScreenshotMode.sleepMinutes, endedAt: .now, deviceID: "screenshot"))
            }
        }
    }
}
