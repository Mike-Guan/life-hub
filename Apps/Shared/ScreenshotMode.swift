import HubCore
import SwiftUI

// Used by .github/workflows/screenshots.yml to draw the README images. Debug builds only.
/// Launch argument `-screenshot-mode <mode>` shows the home screen with fixed, in-memory data.
enum ScreenshotMode {
    static var mode: Mode? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot-mode"), index + 1 < arguments.count else {
            return nil
        }
        return Mode(rawValue: arguments[index + 1])
        #else
        nil
        #endif
    }
}

/// The home screen in `mode`, with no files, permissions or widgets touched.
struct ScreenshotHome: View {
    let mode: Mode
    @State private var store = ModeStore(fileURL: nil, deviceID: "screenshot")
    @State private var energy = EnergyStore(fileURL: nil, deviceID: "screenshot")

    var body: some View {
        // An empty bedtime window, so RUNNER is awake whatever time CI runs.
        HomeView(bedtime: BedtimeSchedule(startMinute: 0, endMinute: 0))
            .environment(store)
            .environment(energy)
            .onAppear {
                // A fresh manual change, so the schedule's 2h hold keeps this mode on screen.
                store.switchTo(mode)
                energy.report(.full)
            }
    }
}
