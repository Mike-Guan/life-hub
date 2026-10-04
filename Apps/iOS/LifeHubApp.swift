import AppIntents
import HubCore
import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

@main
struct LifeHubApp: App {
    @State private var store: ModeStore
    @State private var energy: EnergyStore
    @State private var expenses: ExpenseStore
    @State private var growth: GrowthStore
    @State private var widgets: WidgetBridge
    @State private var setupErrors: [String]
    @State private var bedtime: BedtimeSchedule
    @State private var rules: ModeRules
    @State private var offWorkError: String?
    @State private var reminderError: String?
    @State private var showsSettings = false
    @State private var showsShop = false
    @State private var showsWardrobe = false
    @State private var unboxing: CanEntry?
    @State private var wardrobe = Wardrobe.stored(in: AppGroup.defaults)
    @State private var healthError: String?
    @State private var countdownError: String?
    @State private var screenTimeError: String?
    @State private var places: PlaceSettings
    @State private var budget: BudgetSettings
    @State private var placeMonitor: PlaceMonitor
    @State private var needs: NeedTracker
    @State private var taps: NotificationTaps
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
        let growth = GrowthStore.live(in: container, defaults: AppGroup.defaults)
        _store = State(initialValue: store)
        // The Focus filter switches mode through this store, so the app keeps one writer for the log.
        AppDependencyManager.shared.add { store }
        _energy = State(initialValue: energy)
        _expenses = State(initialValue: ExpenseStore.live(in: container, defaults: AppGroup.defaults))
        UnboxLog.start(with: growth.ledger)
        _growth = State(initialValue: growth)
        _bedtime = State(initialValue: bedtime)
        _rules = State(initialValue: ModeRules.stored(in: AppGroup.defaults))
        _widgets = State(initialValue: widgets)
        _setupErrors = State(initialValue: errors)
        _places = State(initialValue: places)
        _budget = State(initialValue: BudgetSettings.stored(in: AppGroup.defaults))
        _placeMonitor = State(initialValue: placeMonitor)
        _needs = State(initialValue: needs)
        // Set during launch so a tap that opens the app is delivered too. The center keeps it weakly.
        let taps = NotificationTaps(
            onOffWork: { needs.offWork(at: $0) },
            onGo: { date in
                Self.depart(at: date, store: store, energy: energy, widgets: widgets, needs: needs)
            }
        )
        UNUserNotificationCenter.current().delegate = taps
        _taps = State(initialValue: taps)
        // Started here, not in a view: a geofence can launch the app in the background with no UI.
        guard ScreenshotMode.mode == nil else { return }
        _screenTimeError = State(initialValue: Self.restartScrollWatch())
        Self.watch(
            places, with: placeMonitor, store: store, energy: energy, widgets: widgets, needs: needs, growth: growth
        )
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
            rules: rules,
            need: needs.reading,
            activitySignals: needs.activitySignals,
            activityDays: .stored(in: AppGroup.defaults),
            departure: needs.departure,
            event: needs.event,
            invite: needs.invite,
            money: moneyCard,
            onSettings: { showsSettings = true },
            cans: growth.ledger.balance,
            onShop: { showsShop = true },
            wardrobe: wardrobe,
            onWardrobe: { showsWardrobe = true }
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
                earnWins()
                refreshNeeds()
                // The awaits above can include a permission sheet; celebrate only if still on screen.
                if UIApplication.shared.applicationState == .active {
                    needs.celebrate(bedtime: bedtime.state(at: .now))
                    showNextUnboxing()
                }
                countdownError = await BoxingCountdown.update(for: needs.reading)
            }
        }
        .onChange(of: bedtime) {
            bedtime.store(in: AppGroup.defaults)
            widgets.bedtime = bedtime
            syncWidgets()
            Task { await scheduleReminder() }
        }
        .onChange(of: rules) {
            rules.store(in: AppGroup.defaults)
            Task { offWorkError = await OffWorkReminder.schedule(rules) }
            // The work-hours Screen Time watch follows the work hours.
            screenTimeError = Self.restartScrollWatch()
        }
        .onChange(of: places) {
            places.store(in: AppGroup.defaults)
            // A cleared place can't report leaving, so forget being there.
            var presence = PlacePresence.stored(in: AppGroup.defaults)
            presence.leaveAll(except: places.presenceKeys, at: .now)
            presence.store(in: AppGroup.defaults)
            Self.watch(
                places, with: placeMonitor, store: store, energy: energy, widgets: widgets, needs: needs, growth: growth
            )
            refreshNeeds()
        }
        .onChange(of: budget) { budget.store(in: AppGroup.defaults) }
        .sheet(isPresented: $showsSettings, onDismiss: showNextUnboxing) {
            SettingsView(bedtime: $bedtime, rules: $rules, places: $places, budget: $budget, monitor: placeMonitor)
        }
        .fullScreenCover(isPresented: $showsShop, onDismiss: showNextUnboxing) {
            ShopView(growth: growth, wardrobe: $wardrobe)
        }
        .fullScreenCover(isPresented: $showsWardrobe, onDismiss: showNextUnboxing) {
            WardrobeView(growth: growth, wardrobe: $wardrobe, mode: store.current)
        }
        .fullScreenCover(item: $unboxing, onDismiss: showNextUnboxing) { entry in
            UnboxCover(entry: entry, wardrobe: $wardrobe)
        }
        .onChange(of: wardrobe) {
            wardrobe.store(in: AppGroup.defaults)
            WidgetCenter.shared.reloadAllTimelines()
        }
        // A manual mode change ends couch scrolling, so needs are worked out again.
        .onChange(of: store.log.changes.count) { refreshNeeds() }
        .onChange(of: energy.log.events.count) { syncWidgets() }
    }

    private var moneyCard: MoneyCard? {
        guard let target = budget.savingsTarget, let gap = budget.savingsGap(expenses: expenses.log.active) else {
            return nil
        }
        return MoneyCard(gap: gap, target: target)
    }

    // The ledger counts each source once, so re-reading the same workouts earns nothing new.
    private func earnWins() {
        for earned in Win.wins(in: needs.workouts) {
            growth.record(earned.win, source: earned.source, at: earned.at)
        }
    }

    // Keepsakes earned while the app was closed pop open on the home screen, one after another.
    private func showNextUnboxing() {
        guard !showsShop, !showsWardrobe, !showsSettings else { return }
        unboxing = UnboxLog.next(in: growth.ledger)
    }

    private var firstError: String? {
        let errors = [
            widgets.lastError, expenses.lastError, growth.lastError, reminderError, offWorkError, healthError,
            placeMonitor.lastError, needs.lastError, countdownError, screenTimeError,
        ]
        return (setupErrors + errors.compactMap { $0 }).first
    }

    private static func watch(
        _ places: PlaceSettings,
        with monitor: PlaceMonitor,
        store: ModeStore,
        energy: EnergyStore,
        widgets: WidgetBridge,
        needs: NeedTracker,
        growth: GrowthStore
    ) {
        monitor.start(places) { place, entered in
            var presence = PlacePresence.stored(in: AppGroup.defaults)
            let arrived = presence.since(.fitness)
            presence.record(place, entered: entered, at: .now)
            presence.store(in: AppGroup.defaults)
            if place.action == .fitness, !entered, let arrived, let visit = Win.gymVisit(from: arrived, to: .now) {
                growth.record(visit.win, source: visit.source, at: visit.at)
            }
            if let trigger = place.trigger(entered: entered) {
                store.autoSwitch(trigger, rules: .stored(in: AppGroup.defaults))
            }
            needs.refresh(places: places, manualSince: store.log.changes.last(where: \.source.isManual)?.at)
            widgets.need = needs.reading
            widgets.workouts = needs.workouts
            widgets.sync(mode: store, energy: energy)
            WidgetCenter.shared.reloadAllTimelines()
            // Arriving at the gym ends the countdown, even with the app in the background.
            Task { _ = await BoxingCountdown.update(for: needs.reading) }
        }
    }

    // The invite's 走 can run with the app in the background, so this doesn't rely on a view.
    private static func depart(
        at date: Date,
        store: ModeStore,
        energy: EnergyStore,
        widgets: WidgetBridge,
        needs: NeedTracker
    ) {
        GymDeparture(at: date).store(in: AppGroup.defaults)
        let places = PlaceSettings.stored(in: AppGroup.defaults)
        needs.refresh(places: places, manualSince: store.log.changes.last(where: \.source.isManual)?.at)
        widgets.need = needs.reading
        widgets.sync(mode: store, energy: energy)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // Builds before the report ladder watched a single 30-minute event; restarting swaps in the ladder.
    private static func restartScrollWatch() -> String? {
        guard ScrollWatch.hasSelection else { return nil }
        do {
            try ScrollWatch.start(ScrollWatch.selection, work: .stored(in: AppGroup.defaults))
            return nil
        } catch {
            return "Screen Time 监测没启动：\(error.localizedDescription)"
        }
    }

    private func refreshNeeds() {
        needs.refresh(places: places, manualSince: store.log.changes.last(where: \.source.isManual)?.at)
        widgets.need = needs.reading
        widgets.workouts = needs.workouts
        syncWidgets()
    }

    // Pulls in taps made on widgets, then gives widgets the app's view of the state.
    private func syncWidgets() {
        widgets.sync(mode: store, energy: energy, expenses: expenses)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func scheduleReminder() async {
        reminderError = await BedtimeReminder.schedule(bedtime)
        // The bedtime call asks for permission; without it this would fail the same way.
        if reminderError == nil { offWorkError = await OffWorkReminder.schedule(rules) }
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
