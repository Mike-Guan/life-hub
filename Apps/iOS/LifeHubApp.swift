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
    @State private var healthError: String?
    @State private var places: PlaceSettings
    @State private var placeMonitor: PlaceMonitor
    @State private var needs: NeedTracker
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let container = AppGroup.container
        var errors = container.adoptLogs(from: .applicationSupport())
        if !AppGroup.isAvailable {
            errors.append("小组件连不上共享文件夹（App Group），它们会一直是空的")
        }
        let store = ModeStore.live(in: container, defaults: AppGroup.defaults)
        let energy = EnergyStore.live(in: container, defaults: AppGroup.defaults)
        let bedtime = BedtimeSchedule.stored(in: AppGroup.defaults)
        let widgets = WidgetBridge(container: container, bedtime: bedtime)
        let places = PlaceSettings.stored(in: AppGroup.defaults)
        let placeMonitor = PlaceMonitor()
        let needs = NeedTracker()
        _store = State(initialValue: store)
        _energy = State(initialValue: energy)
        _bedtime = State(initialValue: bedtime)
        _widgets = State(initialValue: widgets)
        _setupErrors = State(initialValue: errors)
        _places = State(initialValue: places)
        _placeMonitor = State(initialValue: placeMonitor)
        _needs = State(initialValue: needs)
        // Started here, not in a view: a geofence can launch the app in the background with no UI.
        guard ScreenshotMode.mode == nil else { return }
        Self.watch(places, with: placeMonitor, store: store, energy: energy, widgets: widgets, needs: needs)
    }

    var body: some Scene {
        WindowGroup {
            if let mode = ScreenshotMode.mode {
                ScreenshotHome(mode: mode)
            } else {
                home
            }
        }
    }

    private var home: some View {
        HomeView(
            extraError: firstError,
            bedtime: bedtime,
            need: needs.reading,
            event: needs.event,
            onSettings: { showsSettings = true }
        )
            .environment(store)
            .environment(energy)
            .onChange(of: scenePhase, initial: true) { _, phase in
                guard phase == .active else { return }
                syncWidgets()
                // One after the other, so the two permission prompts don't overlap.
                Task {
                    await scheduleReminder()
                    await importSleep()
                    await needs.importMotion()
                    refreshNeeds()
                    needs.celebrate(bedtime: bedtime.state(at: .now))
                }
            }
            .onChange(of: bedtime) {
                bedtime.store(in: AppGroup.defaults)
                widgets.bedtime = bedtime
                syncWidgets()
                Task { await scheduleReminder() }
            }
            .onChange(of: places) {
                places.store(in: AppGroup.defaults)
                // A cleared place can't report leaving, so forget being there.
                var presence = PlacePresence.stored(in: AppGroup.defaults)
                for kind in HubPlace.Kind.allCases where places[kind] == nil {
                    presence.record(kind, entered: false, at: .now)
                }
                presence.store(in: AppGroup.defaults)
                Self.watch(places, with: placeMonitor, store: store, energy: energy, widgets: widgets, needs: needs)
                refreshNeeds()
            }
            .sheet(isPresented: $showsSettings) {
                SettingsView(bedtime: $bedtime, places: $places, monitor: placeMonitor)
            }
            .onChange(of: store.log.changes.count) { syncWidgets() }
            .onChange(of: energy.log.events.count) { syncWidgets() }
    }

    private var firstError: String? {
        let errors = [widgets.lastError, reminderError, healthError, placeMonitor.lastError, needs.lastError]
        return (setupErrors + errors.compactMap { $0 }).first
    }

    private static func watch(
        _ places: PlaceSettings,
        with monitor: PlaceMonitor,
        store: ModeStore,
        energy: EnergyStore,
        widgets: WidgetBridge,
        needs: NeedTracker
    ) {
        monitor.start(places) { kind, entered in
            var presence = PlacePresence.stored(in: AppGroup.defaults)
            presence.record(kind, entered: entered, at: .now)
            presence.store(in: AppGroup.defaults)
            if let trigger = kind.trigger(entered: entered) {
                store.autoSwitch(trigger)
            }
            needs.refresh(places: places)
            widgets.need = needs.reading
            widgets.sync(mode: store, energy: energy)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func refreshNeeds() {
        needs.refresh(places: places)
        widgets.need = needs.reading
        syncWidgets()
    }

    // Pulls in taps made on widgets, then gives widgets the app's view of the state.
    private func syncWidgets() {
        widgets.sync(mode: store, energy: energy)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func scheduleReminder() async {
        reminderError = await BedtimeReminder.schedule(bedtime)
    }

    // Re-reads each time the app becomes active, so sleep the Watch syncs later still counts.
    private func importSleep() async {
        do {
            if let night = try await HealthSleep.lastNight(), energy.record(night) {
                syncWidgets()
            }
            healthError = nil
        } catch {
            healthError = "读不到健康 App 里的睡眠：\(error.localizedDescription)"
        }
    }
}
