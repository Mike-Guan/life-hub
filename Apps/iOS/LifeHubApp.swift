import AppIntents
import FamilyControls
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
    @State private var welcomeBack: CompanionEvent?
    @State private var persona = Persona.stored(in: AppGroup.defaults)
    @State private var wardrobe = Wardrobe.stored(
        in: AppGroup.defaults,
        persona: Persona.stored(in: AppGroup.defaults)
    )
    @State private var healthError: String?
    @State private var countdownError: String?
    @State private var screenTimeError: String?
    /// The mode HAKU switches from as the app opens, replaying a switch made while it was closed.
    @State private var replayFrom: Mode?
    @State private var places: PlaceSettings
    @State private var budget: BudgetSettings
    @State private var placeMonitor: PlaceMonitor
    @State private var needs: NeedTracker
    @State private var taps: NotificationTaps
    @State private var daily = DailyLink()
    @State private var bathDoneAt = BathTime.doneAt(in: AppGroup.defaults)
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
        WatchSync.shared.activate()
        let growth = GrowthStore.live(in: container, defaults: AppGroup.defaults)
        growth.persona = Persona.stored(in: AppGroup.defaults)
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
                Self.depart(at: date, store: store, energy: energy, widgets: widgets, needs: needs, growth: growth)
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
            workouts: needs.workouts,
            activityDays: ActivityDays.stored(in: AppGroup.defaults).learningGym(from: growth.ledger, now: .now),
            departure: needs.departure,
            event: needs.event,
            welcomeBack: welcomeBack,
            onWelcomeDone: welcomeDone,
            replayFrom: replayFrom,
            invite: needs.invite,
            sit: needs.sit,
            daily: daily.plan,
            dailyDone: daily.done,
            notice: NudgeBackoff.stored(in: AppGroup.defaults).notice(at: .now, persona: persona),
            changes: ChangeEngine.times(log: .stored(in: AppGroup.defaults), ledger: growth.ledger),
            money: moneyCard,
            onSettings: { showsSettings = true },
            cans: growth.ledger.only(persona).balance,
            onShop: { showsShop = true },
            wardrobe: wardrobe,
            persona: persona,
            ledger: growth.ledger.only(persona),
            onWardrobe: { showsWardrobe = true },
            bathDoneAt: bathDoneAt,
            scrollSeenAt: needs.scrollSeenAt,
            onBathDone: {
                BathTime.markDone(at: .now, in: AppGroup.defaults)
                bathDoneAt = .now
                WidgetCenter.shared.reloadAllTimelines()
                sendToWatch()
            }
        )
        .environment(store)
        .environment(energy)
        .onChange(of: scenePhase, initial: true) { old, phase in
            if phase == .background {
                // Launched straight into the background (a place event) isn't Mike leaving the app.
                if old != .background { AppGroup.defaults.set(Date.now, forKey: Self.lastBackgroundKey) }
                replayFrom = nil
                // A box return left halfway was still seen, so it counts toward the 30 days.
                markBoxIfShown()
                welcomeBack = nil
            }
            guard phase == .active else { return }
            let away = AppGroup.defaults.object(forKey: Self.lastBackgroundKey) as? Date
            replayFrom = OpenReplay.switchFrom(log: store.log, lastSeen: away, now: .now)
            // Mike may have changed location access in Settings while away.
            placeMonitor.checkAccess(places)
            syncWidgets()
            // One after the other, so the two permission prompts don't overlap.
            Task {
                // Before rescheduling, which could replace today's delivered notice.
                await replayOffWork()
                await scheduleReminder()
                await importSleep()
                await needs.importMotion()
                await daily.read()
                syncWidgets()
                earnWins()
                refreshNeeds()
                // After earnWins, so wins imported on this open count toward the cards and cans.
                await welcome(away: away)
                // The awaits above can include a permission sheet; celebrate only if still on screen.
                if UIApplication.shared.applicationState == .active {
                    needs.celebrate(bedtime: bedtime.state(at: .now))
                    // Keepsakes open after the welcome back, which may show the same keepsake as a card.
                    if welcomeBack == nil { showNextUnboxing() }
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
            Task { await scheduleOffWork() }
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
            SettingsView(
                bedtime: $bedtime,
                rules: $rules,
                places: $places,
                budget: $budget,
                persona: $persona,
                monitor: placeMonitor,
                daily: daily
            )
        }
        .fullScreenCover(isPresented: $showsShop, onDismiss: showNextUnboxing) {
            ShopView(growth: growth, wardrobe: $wardrobe, persona: persona)
        }
        .fullScreenCover(isPresented: $showsWardrobe, onDismiss: showNextUnboxing) {
            WardrobeView(growth: growth, wardrobe: $wardrobe, persona: persona, mode: store.current)
        }
        .fullScreenCover(item: $unboxing, onDismiss: showNextUnboxing) { entry in
            UnboxCover(entry: entry, wardrobe: $wardrobe, persona: persona)
        }
        .onChange(of: persona) {
            persona.store(in: AppGroup.defaults)
            // New cans and items go to the picked character from now on.
            growth.persona = persona
            // Each character keeps her own wardrobe; storing it again below is harmless.
            wardrobe = Wardrobe.stored(in: AppGroup.defaults, persona: persona)
            // Settings is a sheet, so the scene stays active: refresh here what an open would refresh.
            // Needs reschedule the invite, and the widgets and the watch get the new lines.
            refreshNeeds()
            Task {
                await scheduleReminder()
                countdownError = await BoxingCountdown.update(for: needs.reading)
            }
        }
        .onChange(of: wardrobe) {
            wardrobe.store(in: AppGroup.defaults, persona: persona)
            WidgetCenter.shared.reloadAllTimelines()
            sendToWatch()
        }
        // A manual mode change ends couch scrolling, so needs are worked out again. Watches every write,
        // not the count: undoing a quick switch soft-deletes it and adds nothing.
        .onChange(of: store.revision) {
            refreshNeeds()
            Task { await scheduleOffWork() }
        }
        // A sleep import updates its night in place, so this watches every write too.
        .onChange(of: energy.revision) { syncWidgets() }
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
        // Getting up after an invite is noted by whichever process judged it; the can is earned here.
        for moment in ChangeLog.stored(in: AppGroup.defaults).moments where moment.kind == .gotUp {
            growth.record(.gotUp, source: Win.gotUp.source(at: moment.at), at: moment.at)
        }
        let tasks = DailyAgenda.occurrences(daily.tasks, now: .now)
        for earned in DailyAgenda.wins(in: tasks, ledger: growth.ledger, now: .now) {
            growth.record(earned.win, source: earned.source, at: earned.at)
        }
    }

    // Issue #177: after days away, HAKU shows what was recorded meanwhile. HAKU only until KURO's version is
    // previewed. Events don't play at bedtime, so a return opened then waits for the next open after it.
    private func welcome(away: Date?) async {
        guard let since = ReturnLog.since(away: away, in: AppGroup.defaults) else { return }
        // A return kept from bedtime is dropped once KURO is picked, so it can't play weeks later.
        let playsNow = persona == .haku && bedtime.state(at: .now) == .off
        ReturnLog.setPending(persona == .haku && !playsNow ? since : nil, in: AppGroup.defaults)
        guard playsNow else { return }
        var nights: [SleepNight] = []
        do {
            nights = try await HealthSleep.nights(from: since, to: .now)
        } catch {
            healthError = "读不到健康 App 里的睡眠：\(error.localizedDescription)"
        }
        let replay = ReturnReplay.make(
            lastSeen: since,
            lastBox: ReturnLog.lastBox(in: AppGroup.defaults),
            ledger: growth.ledger.only(persona),
            nights: nights,
            log: store.log,
            now: .now
        )
        guard let replay else { return }
        replayFrom = nil
        welcomeBack = .welcomeBack(id: since.ISO8601Format(), replay: replay)
    }

    // The 30-day limit counts a box return only once it has actually played.
    private func welcomeDone() {
        markBoxIfShown()
        welcomeBack = nil
        showNextUnboxing()
    }

    private func markBoxIfShown() {
        if case .welcomeBack(_, let replay) = welcomeBack, replay.tier == .box {
            ReturnLog.markBox(at: .now, in: AppGroup.defaults)
        }
    }

    // Keepsakes earned while the app was closed pop open on the home screen, one after another.
    private func showNextUnboxing() {
        guard !showsShop, !showsWardrobe, !showsSettings else { return }
        unboxing = UnboxLog.next(in: growth.ledger, persona: persona)
    }

    private var firstError: String? {
        let errors = [
            widgets.lastError, expenses.lastError, growth.lastError, reminderError, offWorkError, healthError,
            placeMonitor.lastError, placeMonitor.accessWarning, needs.lastError, countdownError, screenTimeError,
            daily.lastError,
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
            let arrived = presence.since(place.action == .boxing ? .gym : .fitness)
            let stayStart = presence.since(place)
            if entered, place.action == .fitness, presence.since(.fitness) == nil {
                let departure = GymDeparture.stored(in: AppGroup.defaults)
                let deviceID = HubDevice.id(defaults: AppGroup.defaults)
                if let went = ChangeEngine.wentAfterGo(departure: departure, arrivedAt: .now, deviceID: deviceID) {
                    ChangeLog.note(went, in: AppGroup.defaults)
                }
            }
            presence.record(place, entered: entered, at: .now)
            presence.store(in: AppGroup.defaults)
            if !entered, let arrived, let visit = Win.visit(place.action, from: arrived, to: .now) {
                growth.record(visit.win, source: visit.source, at: visit.at)
            }
            let rules = ModeRules.stored(in: AppGroup.defaults)
            let decision: ModeDecision?
            if !entered, let stayStart, Date.now.timeIntervalSince(stayStart) < PlacePresence.bounce {
                // Walking past a fence takes back the switch the arrival made.
                decision = store.autoSwitch(.passedBy(arrivedAt: stayStart), rules: rules)
            } else if let trigger = place.trigger(entered: entered) {
                // After a GPS-drift return the stay continues; this puts back a mode the leave changed.
                decision = store.autoSwitch(trigger, rules: rules)
            } else {
                decision = nil
            }
            let outcome = decision.map { "切到\($0.mode.title)" } ?? "不切"
            Dogfood.note("geofence", "\(entered ? "到" : "离开")\(place.title)，\(outcome)")
            needs.refresh(
                places: places,
                manualSince: store.log.active.last(where: \.source.isManual)?.at,
                mode: store.current
            )
            widgets.need = needs.reading
            widgets.rules = AppGroup.needRules()
            widgets.workouts = needs.workouts
            widgets.sync(mode: store, energy: energy)
            WidgetCenter.shared.reloadAllTimelines()
            Self.sendToWatch(store: store, needs: needs, growth: growth)
            // Arriving at the gym ends the countdown, even with the app in the background.
            Task { _ = await BoxingCountdown.update(for: needs.reading) }
            // Arriving at or leaving the office decides today's off-work notice.
            let atOffice = presence.since(.office) != nil
            Task { _ = await OffWorkReminder.schedule(rules, mode: store.current, atOffice: atOffice) }
        }
    }

    private static let lastBackgroundKey = "lastBackground"

    // A notice still in Notification Center was never tapped, so its animation never played.
    private func replayOffWork() async {
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        let notice = delivered.first { $0.request.identifier == OffWorkReminder.requestID }
        if OpenReplay.offWork(deliveredAt: notice?.date, mode: store.current, now: .now), let notice {
            needs.offWork(at: notice.date)
        }
    }

    // The invite's 走 can run with the app in the background, so this doesn't rely on a view.
    private static func depart(
        at date: Date,
        store: ModeStore,
        energy: EnergyStore,
        widgets: WidgetBridge,
        needs: NeedTracker,
        growth: GrowthStore
    ) {
        GymDeparture(at: date).store(in: AppGroup.defaults)
        let places = PlaceSettings.stored(in: AppGroup.defaults)
        needs.refresh(
            places: places,
            manualSince: store.log.active.last(where: \.source.isManual)?.at,
            mode: store.current
        )
        widgets.need = needs.reading
        widgets.rules = AppGroup.needRules()
        widgets.sync(mode: store, energy: energy)
        WidgetCenter.shared.reloadAllTimelines()
        Self.sendToWatch(store: store, needs: needs, growth: growth)
    }

    // Builds before the report ladder watched a single 30-minute event; restarting swaps in the ladder.
    private static func restartScrollWatch() -> String? {
        // Without Screen Time HAKU never sees couch scrolling; the dogfood log says why.
        guard ScrollWatch.hasSelection else {
            Dogfood.note("screenTime", "没选 App，不判断刷手机")
            return nil
        }
        if AuthorizationCenter.shared.authorizationStatus != .approved {
            Dogfood.note("screenTime", "没授权，不判断刷手机")
        }
        do {
            try ScrollWatch.start(ScrollWatch.selection, work: .stored(in: AppGroup.defaults))
            return nil
        } catch {
            Dogfood.note("screenTime", "监测没启动：\(error.localizedDescription)")
            return "Screen Time 监测没启动：\(error.localizedDescription)"
        }
    }

    private func refreshNeeds() {
        needs.refresh(
            places: places,
            manualSince: store.log.active.last(where: \.source.isManual)?.at,
            mode: store.current
        )
        widgets.need = needs.reading
        widgets.rules = AppGroup.needRules()
        widgets.workouts = needs.workouts
        syncWidgets()
    }

    // Pulls in taps made on widgets, then gives widgets the app's view of the state.
    private func syncWidgets() {
        widgets.sync(mode: store, energy: energy, expenses: expenses)
        WidgetCenter.shared.reloadAllTimelines()
        sendToWatch()
    }

    private func sendToWatch() {
        Self.sendToWatch(store: store, needs: needs, growth: growth)
    }

    // The watch plays the home card's scenes, worked out from the same inputs as HomeView. Static, so
    // place events in the background can send too; settings come from the App Group, where they are saved.
    private static func sendToWatch(store: ModeStore, needs: NeedTracker, growth: GrowthStore) {
        let inputs = HomeSceneInputs(
            log: store.log,
            rules: ModeRules.stored(in: AppGroup.defaults),
            bedtime: BedtimeSchedule.stored(in: AppGroup.defaults),
            need: needs.reading,
            signals: needs.activitySignals,
            days: ActivityDays.stored(in: AppGroup.defaults).learningGym(from: growth.ledger, now: .now),
            departure: needs.departure,
            sit: needs.sit,
            bathDoneAt: BathTime.doneAt(in: AppGroup.defaults)
        )
        WatchSync.shared.send(scenes: inputs.timeline(from: .now))
    }

    private func scheduleOffWork() async {
        let atOffice = PlacePresence.stored(in: AppGroup.defaults).since(.office) != nil
        offWorkError = await OffWorkReminder.schedule(rules, mode: store.current, atOffice: atOffice)
    }

    private func scheduleReminder() async {
        reminderError = await BedtimeReminder.schedule(bedtime, persona: persona)
        // The bedtime call asks for permission; without it this would fail the same way.
        if reminderError == nil { await scheduleOffWork() }
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
