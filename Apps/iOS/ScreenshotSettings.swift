import HubCore
import SwiftUI

// Used by scripts/screenshots.sh to draw the 删除全部数据 card for UI 审核. Debug builds only.
// Nothing is stored: the settings are read once and erasing does nothing.
/// The bottom of Settings, with the erase confirmation open when `asksErase`.
struct ScreenshotSettings: View {
    let asksErase: Bool
    @State private var store = ModeStore(fileURL: nil, deviceID: "screenshot")
    @State private var energy = EnergyStore(fileURL: nil, deviceID: "screenshot")
    @State private var monitor = PlaceMonitor()
    @State private var daily = DailyLink()

    var body: some View {
        SettingsView(
            bedtime: .constant(.stored(in: AppGroup.defaults)),
            rules: .constant(.stored(in: AppGroup.defaults)),
            places: .constant(PlaceSettings()),
            budget: .constant(BudgetSettings()),
            persona: .constant(ScreenshotMode.persona),
            monitor: monitor,
            daily: daily,
            store: store,
            energy: energy,
            ledger: CanLedger(),
            onEraseAll: {},
            screenshot: asksErase
        )
    }
}
