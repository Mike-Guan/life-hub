import HubCore
import SwiftUI
import WidgetKit

@main
struct LifeHubApp: App {
    @State private var store: ModeStore
    @State private var energy: EnergyStore
    @State private var widgets: WidgetBridge
    @State private var setupErrors: [String]
    @State private var bedtime: BedtimeSchedule
    @State private var reminderError: String?
    @State private var showsSettings = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let container = AppGroup.container
        var errors = container.adoptLogs(from: .applicationSupport())
        if !AppGroup.isAvailable {
            errors.append("小组件连不上共享文件夹（App Group），它们会一直是空的")
        }
        _store = State(initialValue: ModeStore.live(in: container, defaults: AppGroup.defaults))
        _energy = State(initialValue: EnergyStore.live(in: container, defaults: AppGroup.defaults))
        let bedtime = BedtimeSchedule.stored(in: AppGroup.defaults)
        _bedtime = State(initialValue: bedtime)
        _widgets = State(initialValue: WidgetBridge(container: container, bedtime: bedtime))
        _setupErrors = State(initialValue: errors)
    }

    var body: some Scene {
        WindowGroup {
            HomeView(extraError: firstError, bedtime: bedtime, onSettings: { showsSettings = true })
                .environment(store)
                .environment(energy)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    guard phase == .active else { return }
                    syncWidgets()
                    scheduleReminder()
                }
                .onChange(of: bedtime) {
                    bedtime.store(in: AppGroup.defaults)
                    widgets.bedtime = bedtime
                    syncWidgets()
                    scheduleReminder()
                }
                .sheet(isPresented: $showsSettings) {
                    SettingsView(bedtime: $bedtime)
                }
                .onChange(of: store.log.changes.count) { syncWidgets() }
                .onChange(of: energy.log.events.count) { syncWidgets() }
        }
    }

    private var firstError: String? {
        (setupErrors + [widgets.lastError, reminderError].compactMap { $0 }).first
    }

    // Pulls in taps made on widgets, then gives widgets the app's view of the state.
    private func syncWidgets() {
        widgets.sync(mode: store, energy: energy)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func scheduleReminder() {
        Task { reminderError = await BedtimeReminder.schedule(bedtime) }
    }
}
