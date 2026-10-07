import HubCore
import SwiftUI

// Draws RUNNER from vector parts with SwiftUI motion. When `runner.riv` exists this view
// switches to Rive internally; callers keep passing `mode`, `energy` and `cheer`.
/// RUNNER, reacting to the current mode and energy.
public struct CompanionView: View {
    let mode: Mode?
    /// Energy 0-100, or nil when unknown. Below 30 RUNNER looks tired; from 70 it looks bright.
    let energy: Double?
    /// What RUNNER acts out on top of the mode, or nil.
    let need: CompanionNeed?
    /// When `need` started. After 30 minutes of couch scrolling HAKU starts eyeing the gym bag.
    let needSince: Date?
    /// What HAKU does alongside Mike, such as heavy-bag combos at the boxing gym. It replaces the need.
    let activity: CompanionActivity?
    /// The state within the mode HAKU acts out, such as vibe coding. It replaces the need.
    let moment: CompanionMoment?
    /// Monster cans piled up next to HAKU while vibe coding.
    let codingCans: Int
    /// What today left in HAKU's world, such as a bandage after boxing.
    let traces: Set<CompanionTrace>
    /// HAKU's hidden params; they change only how it moves and looks.
    let vitals: HakuVitals
    // To show a new item after its unboxing, pass a `wardrobe` with it equipped and its slot's `showcaseMode`.
    /// A one-off animation: celebrating a workout, going off work, unboxing an item or staying home.
    /// Each event id plays once.
    let event: CompanionEvent?
    /// A planned Daily Widget task starting soon or now: HAKU holds up its prop, and slaps a sticky note on the
    /// screen once as it starts.
    let daily: DailyCue?
    /// The place Mike just left: HAKU walks with what it carries from there, unless a task scene or an activity
    /// shows.
    let walking: HubPlace.Kind?
    /// On the way between home and the office: HAKU walks or rides with the leg's own look, unless a task scene
    /// or an activity shows.
    let commute: CommutePhase?
    /// Bath time before bed: HAKU carries shampoo and a rubber duck out of the frame; a tap dries its hair.
    let bath: Bool
    /// Called after HAKU dries its hair on a tap during bath time.
    let onBathDone: (() -> Void)?
    /// Today's invite, written by the app. While set, RUNNER gets up, jumps and says it.
    let invite: String?
    /// Increment to play the cheer jump.
    let cheer: Int
    /// `.on` turns RUNNER sleepy; each change to `.on` plays the good-night animation once.
    let bedtime: Bedtime
    /// What HAKU wears from the shop and keepsakes.
    let wardrobe: Wardrobe
    let style: CompanionStyle
    let showsBubble: Bool
    /// Called after HAKU reacts to a tap, for example to switch the 副业 state.
    let onTap: (() -> Void)?
    /// Called once the welcome back scene ends or is skipped with a tap.
    let onWelcomeDone: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var pop = 0
    @State private var taps = 0
    @State private var goodnightStart: Date?
    // Seconds since the reference date of the last good-night animation, shared by every CompanionView.
    @AppStorage("companion.lastGoodnight") private var lastGoodnight: Double = 0
    @State private var celebrationStart: Date?
    @State private var celebrationKind: WorkoutSummary.Kind?
    @State private var inviteJumps = 0
    // Id of the last celebrated workout, shared by every CompanionView so each plays once.
    @AppStorage("companion.lastCelebration") private var lastCelebration = ""
    @State private var offWorkStart: Date?
    // Day of the last off-work animation, shared by every CompanionView so it plays once a day.
    @AppStorage("companion.lastOffWork") private var lastOffWork = ""
    @State private var unlockStart: Date?
    // Id of the last unboxing, shared by every CompanionView so each plays once.
    @AppStorage("companion.lastUnlock") private var lastUnlock = ""
    @State private var stayHomeStart: Date?
    // Day HAKU last gave up on leaving, shared by every CompanionView so it plays once a day.
    @AppStorage("companion.lastStayHome") private var lastStayHome = ""
    @State private var swapStart: Date?
    @State private var noticeStart: Date?
    // Seconds since the reference date when the app was last open, shared by every CompanionView.
    @AppStorage("companion.lastSeen") private var lastSeen: Double = 0
    @State private var noticeLookUp = false
    // Night (day of its evening) HAKU last said "还不睡。", shared by every CompanionView so it is said once a
    // night.
    @AppStorage("companion.lastLateNight") private var lastLateNight = ""
    @State private var lateNightStart: Date?
    // A napping HAKU only rolls over on the first tap; a second tap soon after half wakes it.
    @State private var rollStart: Date?
    @State private var tapTimes: [Date] = []
    @State private var turnAwayStart: Date?
    @State private var pokeStart: Date?
    @State private var pokeKind: WatchPoke?
    @State private var pokes = 0
    @State private var whistleStart: Date?
    @State private var stretchUpStart: Date?
    // Seconds since the reference date of the last stretch on opening while stiff, shared by every CompanionView.
    @AppStorage("companion.lastStretchUp") private var lastStretchUp: Double = 0
    @State private var limberStart: Date?
    // Id of the last shoulder roll after standing up, shared by every CompanionView so each plays once.
    @AppStorage("companion.lastStretched") private var lastStretched = ""
    @State private var packUpStart: Date?
    // Seconds since the reference date HAKU last started packing up, shared by every CompanionView.
    @AppStorage("companion.lastPackUp") private var lastPackUp: Double = 0
    @State private var slapStart: Date?
    // Ids of the last planned tasks HAKU reacted to before and at their start, shared by every CompanionView so
    // each plays once.
    @AppStorage("companion.lastDailySoon") private var lastDailySoon = ""
    @AppStorage("companion.lastDailyNow") private var lastDailyNow = ""
    @State private var doneStart: Date?
    @State private var doneFocus = false
    // Id of the last planned task cheered as done, shared by every CompanionView so each plays once.
    @AppStorage("companion.lastTaskDone") private var lastTaskDone = ""
    @State private var dryStart: Date?
    @State private var reviveStart: Date?
    // Id of the last time HAKU got up from the sofa, shared by every CompanionView so each plays once.
    @AppStorage("companion.lastRevived") private var lastRevived = ""
    @State private var welcomeStart: Date?
    @State private var welcomeReplay: ReturnReplay?
    @State private var welcomeTask: Task<Void, Never>?
    // Id of the last welcome back, shared by every CompanionView so each plays once.
    @AppStorage("companion.lastWelcome") private var lastWelcome = ""
    @State private var bubble: String?
    @State private var bubbleTask: Task<Void, Never>?

    public init(
        mode: Mode?,
        energy: Double? = nil,
        need: CompanionNeed? = nil,
        needSince: Date? = nil,
        activity: CompanionActivity? = nil,
        moment: CompanionMoment? = nil,
        codingCans: Int = 0,
        traces: Set<CompanionTrace> = [],
        vitals: HakuVitals = HakuVitals(),
        event: CompanionEvent? = nil,
        daily: DailyCue? = nil,
        walking: HubPlace.Kind? = nil,
        commute: CommutePhase? = nil,
        bath: Bool = false,
        invite: String? = nil,
        cheer: Int = 0,
        bedtime: Bedtime = .off,
        wardrobe: Wardrobe = Wardrobe(),
        style: CompanionStyle = .standard,
        showsBubble: Bool = true,
        onTap: (() -> Void)? = nil,
        onBathDone: (() -> Void)? = nil,
        onWelcomeDone: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.energy = energy
        self.need = need
        self.needSince = needSince
        self.activity = activity
        self.moment = moment
        self.codingCans = codingCans
        self.traces = traces
        self.vitals = vitals
        self.event = event
        self.daily = daily
        self.walking = walking
        self.commute = commute
        self.bath = bath
        self.invite = invite
        self.cheer = cheer
        self.bedtime = bedtime
        self.wardrobe = wardrobe
        self.style = style
        self.showsBubble = showsBubble
        self.onTap = onTap
        self.onBathDone = onBathDone
        self.onWelcomeDone = onWelcomeDone
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(mode?.color ?? Toy.paper)
                .overlay { Toy.ink.opacity(bedtime == .on ? 0.35 : 0) }
                .animation(.easeInOut(duration: 0.25), value: mode)
                .animation(.easeInOut(duration: 0.8), value: bedtime)

            character
                .padding(.top, 24)
                .padding(.horizontal, 12)

            if welcomeStart != nil, let replay = welcomeReplay {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: paused)) { context in
                    welcomeChips(replay, at: context.date.timeIntervalSinceReferenceDate)
                }
            }

            if showsBubble, let bubble {
                SpeechBubble(text: bubble)
                    .padding(12)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: style == .watch ? .bottom : .topLeading
                    )
                    .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { react() }
        .sensoryFeedback(.impact(weight: .light), trigger: pokes)
        .onChange(of: mode) { _, _ in
            pop += 1
            // The welcome back keeps its line through a mode change (issue #184).
            if welcomeStart == nil { say(nil) }
        }
        .onAppear {
            startNotice()
            startStretchUp()
            startPackUp()
            startCue()
            if bedtime == .on, !Self.playedTonight(last: lastGoodnight, now: .now) { startGoodnight() }
            playEventIfNew()
            if invite != nil { startInvite() }
            if bath { say(Self.bathLine, for: 3) }
        }
        .onChange(of: bath) { _, new in
            guard new else { return }
            // The view lives for days, so each evening's bath time starts with dry hair.
            dryStart = nil
            say(Self.bathLine, for: 3)
        }
        .onChange(of: invite) { _, new in
            if new != nil { startInvite() }
        }
        .onChange(of: event) { _, _ in playEventIfNew() }
        .onChange(of: daily) { _, _ in startCue() }
        .onChange(of: scenePhase) { _, new in
            if new == .active {
                startNotice()
                startStretchUp()
                startPackUp()
                startCue()
            }
            if new == .background { lastSeen = Date.now.timeIntervalSinceReferenceDate }
        }
        .onChange(of: moment) { _, _ in
            startPackUp()
            pop += 1
            swapStart = .now
            say(nil)
        }
        .onChange(of: bedtime) { _, new in
            if new == .on { startGoodnight() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var character: some View {
        if let mode {
            KeyframeAnimator(initialValue: 0.0, trigger: taps) { react in
                TimelineView(.animation(minimumInterval: 1 / 30, paused: paused)) { context in
                    let time = context.date.timeIntervalSinceReferenceDate
                    let life = idleLife(mode, at: context.date)
                    let motion = idleMotion(mode, life: life, time: time)
                    RunnerFigure(
                        mode: mode,
                        pose: pose(mode, life: life, time: time, react: react).wearing(Outfit(wardrobe)).leaving(traces)
                    )
                    .saturation(vitals.saturation)
                    .brightness(vitals.brightness)
                    .rotationEffect(.degrees(reduceMotion ? 0 : motion.angle), anchor: .bottom)
                    .offset(y: reduceMotion ? 0 : motion.dy)
                }
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(1, duration: 0.15)
                    LinearKeyframe(1, duration: 0.35)
                    CubicKeyframe(0, duration: 0.3)
                }
            }
            .id(mode)
            .transition(.opacity)
            .keyframeAnimator(initialValue: Squash(), trigger: pop) { content, value in
                content.scaleEffect(x: value.x, y: value.y, anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack(\.x) {
                    CubicKeyframe(1.07, duration: 0.08)
                    SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                }
                KeyframeTrack(\.y) {
                    CubicKeyframe(0.9, duration: 0.08)
                    SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                }
            }
            .keyframeAnimator(initialValue: 0.0, trigger: cheer + inviteJumps) { content, lift in
                content.offset(y: -lift)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(0, duration: 0.05)
                    SpringKeyframe(36, duration: 0.18)
                    SpringKeyframe(0, duration: 0.45, spring: .bouncy)
                }
            }
            .modifier(WatchFigureFrame(isEnabled: style == .watch))
        } else {
            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .black))
                Text("选一个 mode，HAKU 就上线")
                    .font(Toy.body(15, weight: .bold))
            }
            .foregroundStyle(Toy.ink)
        }
    }

    private var face: EnergyFace { EnergyFace(energy: energy) }

    /// The need RUNNER acts out: none while it is inviting, since it got up, or busy with an activity or moment.
    private var shownNeed: CompanionNeed? { invite == nil && activity == nil && moment == nil ? need : nil }

    /// The moment HAKU acts out: an activity takes precedence.
    private var shownMoment: CompanionMoment? { activity == nil ? moment : nil }

    private var accessibilityText: String {
        if welcomeStart != nil, let replay = welcomeReplay { return CompanionLines.welcomeLabel(replay) }
        let life = mode.flatMap { idleLife($0, at: .now) }
        let peeking = couchStage(at: .now) == .peeking
        return CompanionLines.accessibilityLabel(
            mode: mode,
            need: shownNeed,
            peeking: peeking,
            life: life,
            activity: activity,
            moment: shownMoment,
            bedtime: bedtime
        )
    }

    /// The couch scrolling stage, or nil when HAKU isn't on the couch.
    private func couchStage(at date: Date) -> CouchStage? {
        guard need == .couchScroll, activity == nil, moment == nil, bedtime == .off else { return nil }
        return CouchStage.at(date, since: needSince, inviting: invite != nil)
    }

    /// What HAKU does on its own: only at home (chill), with nothing needed, awake and no event playing.
    private func idleLife(_ mode: Mode, at date: Date) -> IdleLife? {
        let time = date.timeIntervalSinceReferenceDate
        let busy = celebration(at: time) != nil || taskDone(at: time) != nil || stillOneOff(at: time)
        let free =
            need == nil && activity == nil && moment == nil && daily == nil && invite == nil && walking == nil
            && !bath
        guard mode == .chill, free, bedtime == .off, !busy else {
            return nil
        }
        return IdleLife.at(date, stamina: vitals.stamina)
    }

    private var paused: Bool { reduceMotion || scenePhase != .active }

    private func idleMotion(_ mode: Mode, life: IdleLife?, time: TimeInterval) -> IdleMotion {
        if pokeKind == .rollOver, let progress = poke(at: time) {
            return IdleMotion.rollingOver(time: time, progress: progress)
        }
        if bedtime == .off, life == .nap,
            let progress = Self.progress(since: rollStart, at: time, duration: Self.rollDuration)
        {
            return IdleMotion.rollingOver(time: time, progress: progress)
        }
        if bedtime == .on || life == .nap { return IdleMotion.sleeping(time: time) }
        if stillOneOff(at: time) { return IdleMotion(dy: 0, angle: 0) }
        if let progress = celebration(at: time) ?? taskDone(at: time) {
            return IdleMotion.celebrating(progress: progress)
        }
        let pace = face.speed * vitals.motionSpeed
        if let moment = shownMoment { return IdleMotion(moment: moment, mode: mode, time: time * pace) }
        // Warming up hops like boxing day, whatever the outfit.
        if shownNeed == .couchScroll { return IdleMotion.slumped(time: time) }
        // Running and heavy-bag work bounce like boxing day, running a bit quicker.
        if activity == .running { return IdleMotion(mode: .boxing, time: time * 1.6) }
        if activity == .boxingAtGym { return IdleMotion(mode: .boxing, time: time * pace) }
        let motionMode = shownNeed == .boxingWarmup ? .boxing : mode
        return IdleMotion(mode: motionMode, time: time * pace).bouncing(vitals.bounce)
    }

    private func pose(_ mode: Mode, life: IdleLife?, time: TimeInterval, react: Double) -> RunnerPose {
        if bedtime == .on { return bedtimePose(time: time) }
        if let progress = offWork(at: time) {
            return RunnerPose.offWork(time: time, progress: reduceMotion ? 1 : progress, face: face)
        }
        if let progress = stayHome(at: time) {
            return RunnerPose.stayHome(time: time, progress: reduceMotion ? 1 : progress, face: face)
        }
        if let progress = limber(at: time) {
            return RunnerPose.limber(time: time, progress: reduceMotion ? 1 : progress, face: face)
        }
        if let progress = revive(at: time) {
            // Reduced motion holds the last frame: standing with the mask up.
            let t = reduceMotion ? RunnerPose.reviveLength - 0.5 : CGFloat(progress) * RunnerPose.reviveLength
            return RunnerPose.revive(time: t, face: face)
        }
        if let replay = welcomeReplay, let t = welcome(at: time) {
            let scene = WelcomeScene(replay, mode: mode)
            let open = scene.open(cards: replay.cards.count, cans: replay.cans)
            // Reduced motion holds the last frame.
            let shown = reduceMotion ? scene.length(cards: replay.cards.count, cans: replay.cans) - 0.2 : t
            return RunnerPose.welcome(scene, time: shown, open: open, face: face)
        }
        let stage = couchStage(at: Date(timeIntervalSinceReferenceDate: time))
        if reduceMotion {
            var pose = RunnerPose(face: face, need: shownNeed, life: life, activity: activity, moment: shownMoment)
            pose.codingCans = codingCans
            if stage == .peeking { pose.bagLift = 0 }
            if stage == .up { pose.bagLift = 1 }
            pose.headDy += vitals.slouch
            if turnAway(at: time) != nil { pose.turnedAway = true }
            if let commute, daily?.scene == nil, activity == nil {
                pose.commute(commute, time: 0.2)
            } else if let walking, daily?.scene == nil, activity == nil {
                pose.walk(from: walking, time: 0.2)
            }
            if bath { pose.callToBath(time: 0.5) }
            if let daily { pose.cue(daily, time: 5, slap: nil) }
            return pose
        }
        var pose = RunnerPose(
            mode: mode,
            time: time * vitals.motionSpeed,
            face: face,
            need: shownNeed,
            life: life,
            activity: activity,
            moment: shownMoment,
            react: react
        )
        pose.codingCans = codingCans
        pose.headDy += vitals.slouch
        if stage == .peeking { pose.peekAtBag(time: time) }
        if stage == .up { pose.bagLift = 1 }
        if let progress = Self.progress(since: swapStart, at: time, duration: Self.swapDuration) {
            // Switching state: a quick burst of sparkles over the squash.
            pose.burst = CGFloat(progress)
        }
        if let commute, daily?.scene == nil, activity == nil {
            pose.commute(commute, time: CGFloat(time))
        } else if let walking, daily?.scene == nil, activity == nil {
            pose.walk(from: walking, time: CGFloat(time))
        }
        if let progress = Self.progress(since: dryStart, at: time, duration: RunnerPose.bathDryLength) {
            pose.dryHair(time: CGFloat(progress * RunnerPose.bathDryLength))
        } else if bath {
            pose.callToBath(time: CGFloat(time))
        }
        if let daily { pose.cue(daily, time: time, slap: slap(at: time)) }
        if let progress = celebration(at: time) { pose.celebrate(celebrationKind, progress: CGFloat(progress)) }
        if let progress = taskDone(at: time) {
            if doneFocus {
                pose.cheerFocus(progress: progress)
            } else {
                // The peace sign from a run's celebration.
                pose.celebrate(.running, progress: CGFloat(progress))
            }
        }
        if let progress = unlock(at: time) { pose.unbox(progress: CGFloat(progress)) }
        if let progress = Self.progress(since: noticeStart, at: time, duration: noticeDuration),
            life != .nap, !stillOneOff(at: time), celebration(at: time) == nil
        {
            pose.notice(progress: progress, lookUp: noticeLookUp)
        }
        if let pokeKind, let progress = poke(at: time) { pose.poke(pokeKind, progress: progress) }
        if let progress = turnAway(at: time) { pose.turnAway(progress: progress) }
        if shownMoment == .stiff, let progress = stretchUp(at: time) { pose.stretchUp(progress: progress) }
        if shownMoment == .packingUp, let start = packUpStart?.timeIntervalSinceReferenceDate,
            time - start < RunnerPose.packUpLength
        {
            pose.packUp(elapsed: max(0, time - start))
        }
        if life == .snack || life == .drawing,
            let progress = Self.progress(since: whistleStart, at: time, duration: Self.whistleDuration)
        {
            pose.whistle(progress: progress)
        }
        if vitals.spirit == .low, shownNeed == nil, shownMoment == nil, life == nil, activity == nil,
            let progress = Self.rubEyes(at: time * vitals.motionSpeed, mode: mode)
        {
            pose.rubEyes(progress: progress)
        }
        if vitals.spirit == .high, shownNeed == nil, shownMoment == nil, life == nil, activity == nil,
            let progress = Self.hum(at: time * vitals.motionSpeed)
        {
            pose.hum = CGFloat(progress)
        }
        if Self.progress(since: lateNightStart, at: time, duration: Self.lateNightDuration) != nil {
            // Opened after midnight: a squint at you.
            pose.blink = min(pose.blink, 0.4)
        }
        return pose
    }

    /// Starts the notice turn as the app opens, as a slow look up when the app was closed for half a day.
    private func startNotice() {
        let now = Date.now
        // Cold launch calls this on appear and again on .active; keep the first, which knows how long the app was away.
        guard !Self.noticePlaying(since: noticeStart, now: now, duration: noticeDuration) else { return }
        noticeLookUp = Self.backAfterLongAway(lastSeen: lastSeen, now: now)
        lastSeen = now.timeIntervalSinceReferenceDate
        noticeStart = now
        if let night = Self.newLateNight(at: now, last: lastLateNight) {
            lastLateNight = night
            lateNightStart = now
            bubbleTask?.cancel()
            bubbleTask = Task {
                try? await Task.sleep(for: .seconds(noticeDuration))
                guard !Task.isCancelled else { return }
                say("还不睡。", for: 3)
            }
        }
    }

    /// Starts the stretch as the app opens while HAKU is stiff, at most once every 30 minutes.
    private func startStretchUp() {
        let now = Date.now
        guard shownMoment == .stiff, bedtime == .off, Self.stretchUpDue(last: lastStretchUp, now: now) else { return }
        lastStretchUp = now.timeIntervalSinceReferenceDate
        stretchUpStart = now
        bubbleTask?.cancel()
        bubbleTask = Task {
            try? await Task.sleep(for: .seconds(Self.stretchUpDuration * 0.57))
            guard !Task.isCancelled else { return }
            say("……我腰要断了。你呢？", for: 3)
        }
    }

    /// Starts packing up from closing the laptop, unless it started within the past 20 minutes; then HAKU is
    /// already packed and just watches the clock.
    private func startPackUp() {
        let now = Date.now
        guard shownMoment == .packingUp, bedtime == .off, Self.packUpDue(last: lastPackUp, now: now) else { return }
        lastPackUp = now.timeIntervalSinceReferenceDate
        packUpStart = now
    }

    /// Says the planned task's line once before its start, and slaps the sticky note on once as it starts.
    private func startCue() {
        guard bedtime == .off, let daily else { return }
        switch daily.stage {
        case .soon:
            guard let id = Self.newCue(daily, stage: .soon, last: lastDailySoon) else { return }
            lastDailySoon = id
            say("还有 15 分钟。我先替你紧张一下。", for: 3.5)
        case .now:
            guard let id = Self.newCue(daily, stage: .now, last: lastDailyNow) else { return }
            lastDailyNow = id
            slapStart = .now
            say("到点了。")
        }
    }

    /// The id of `cue` when it is at `stage` and didn't play yet, else nil.
    nonisolated static func newCue(_ cue: DailyCue?, stage: DailyCue.Stage, last: String) -> String? {
        guard let cue, cue.stage == stage, cue.id != last else { return nil }
        return cue.id
    }

    /// Progress of the sticky note on the screen at `time`, 0..<1, or nil when it isn't.
    private func slap(at time: TimeInterval) -> Double? {
        Self.progress(since: slapStart, at: time, duration: RunnerPose.noteSlapLength)
    }

    /// Progress of cheering a planned task done at `time`, 0..<1, or nil when none is playing.
    private func taskDone(at time: TimeInterval) -> Double? {
        Self.progress(since: doneStart, at: time, duration: doneFocus ? Self.focusDoneDuration : Self.doneDuration)
    }

    /// Whether packing up plays from the start again, 20 minutes after the `last` time.
    nonisolated static func packUpDue(last: TimeInterval, now: Date) -> Bool {
        now.timeIntervalSinceReferenceDate - last >= 20 * 60
    }

    /// Whether the stretch on opening may play again, 30 minutes after the `last` one.
    nonisolated static func stretchUpDue(last: TimeInterval, now: Date) -> Bool {
        now.timeIntervalSinceReferenceDate - last >= 30 * 60
    }

    /// Progress of the stretch on opening at `time`, 0..<1, or nil when none is playing.
    private func stretchUp(at time: TimeInterval) -> Double? {
        Self.progress(since: stretchUpStart, at: time, duration: Self.stretchUpDuration)
    }

    /// Progress of rolling the shoulders at `time`, 0..<1, or nil when none is playing.
    private func limber(at time: TimeInterval) -> Double? {
        Self.progress(since: limberStart, at: time, duration: Self.limberDuration)
    }

    /// Progress of getting up from the sofa at `time`, 0..<1, or nil when none is playing.
    private func revive(at time: TimeInterval) -> Double? {
        Self.progress(since: reviveStart, at: time, duration: Double(RunnerPose.reviveLength))
    }

    /// Seconds into the welcome back scene at `time`, or nil when none is playing.
    private func welcome(at time: TimeInterval) -> CGFloat? {
        guard let start = welcomeStart?.timeIntervalSinceReferenceDate, let replay = welcomeReplay else { return nil }
        let length = WelcomeScene(replay, mode: mode ?? .chill).length(cards: replay.cards.count, cans: replay.cans)
        let t = CGFloat(time - start)
        return t >= 0 && t < length ? t : nil
    }

    /// The card flipped over at the top, or at the bottom when there is no crate, then the cans chip.
    @ViewBuilder private func welcomeChips(_ replay: ReturnReplay, at time: TimeInterval) -> some View {
        let scene = WelcomeScene(replay, mode: mode ?? .chill)
        let open = scene.open(cards: replay.cards.count, cans: replay.cans)
        if let t = welcome(at: time) {
            let shown = reduceMotion ? scene.length(cards: replay.cards.count, cans: replay.cans) - 0.2 : t
            Group {
                if let open, shown >= open + WelcomeScene.cansChip {
                    CansChip(cans: replay.cans)
                } else if let index = scene.card(at: shown, count: replay.cards.count, open: open) {
                    let flip = min((shown - scene.firstCard - CGFloat(index) * WelcomeScene.cardGap) / 0.3, 1)
                    ReturnCardChip(card: replay.cards[index])
                        .rotation3DEffect(.degrees(reduceMotion ? 0 : 90 * Double(1 - flip)), axis: (x: 0, y: 1, z: 0))
                        .id(index)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: scene.crate ? .top : .bottom)
            .allowsHitTesting(false)
        }
    }

    /// Progress of turning away after being tapped too often at `time`, 0..<1, or nil when not turned away.
    private func turnAway(at time: TimeInterval) -> Double? {
        let duration = style == .watch ? WatchPoke.turnAwayDuration : Self.turnAwayDuration
        return Self.progress(since: turnAwayStart, at: time, duration: duration)
    }

    /// Progress of the reaction to a watch poke at `time`, 0..<1, or nil when none is playing.
    private func poke(at time: TimeInterval) -> Double? {
        Self.progress(since: pokeStart, at: time, duration: WatchPoke.duration)
    }

    /// Progress of the celebration at `time`, 0..<1, or nil when none is playing.
    private func celebration(at time: TimeInterval) -> Double? {
        Self.progress(since: celebrationStart, at: time, duration: Self.celebrationDuration)
    }

    /// Progress of the off-work animation at `time`, 0..<1, or nil when none is playing.
    private func offWork(at time: TimeInterval) -> Double? {
        Self.progress(since: offWorkStart, at: time, duration: Self.offWorkDuration)
    }

    /// Progress of the unboxing at `time`, 0..<1, or nil when none is playing.
    private func unlock(at time: TimeInterval) -> Double? {
        Self.progress(since: unlockStart, at: time, duration: Self.unlockDuration)
    }

    /// Progress of giving up on leaving at `time`, 0..<1, or nil when none is playing.
    private func stayHome(at time: TimeInterval) -> Double? {
        Self.progress(since: stayHomeStart, at: time, duration: Self.stayHomeDuration)
    }

    /// Whether a one-off animation that holds HAKU still is playing: off work, unboxing, staying home,
    /// stretching, rolling the shoulders, getting up from the sofa or the welcome back.
    private func stillOneOff(at time: TimeInterval) -> Bool {
        offWork(at: time) != nil || unlock(at: time) != nil || stayHome(at: time) != nil
            || stretchUp(at: time) != nil || limber(at: time) != nil || revive(at: time) != nil
            || welcome(at: time) != nil
    }

    private static func progress(since start: Date?, at time: TimeInterval, duration: Double) -> Double? {
        guard let start = start?.timeIntervalSinceReferenceDate else { return nil }
        let progress = (time - start) / duration
        return (0..<1).contains(progress) ? progress : nil
    }

    private func bedtimePose(time: TimeInterval) -> RunnerPose {
        if reduceMotion { return RunnerPose.bedtimeStill() }
        switch style {
        case .standard, .watch:
            let start = goodnightStart?.timeIntervalSinceReferenceDate ?? -.infinity
            let goodnight = (time - start) / Self.goodnightDuration
            return RunnerPose.bedtime(time: time, goodnight: goodnight, liesDown: true)
        case .notification:
            let loop = time.truncatingRemainder(dividingBy: Self.notificationLoop) / Self.notificationLoop
            return RunnerPose.bedtime(time: time, goodnight: loop, liesDown: false)
        }
    }

    private static let goodnightDuration = 3.2
    private static let celebrationDuration = 1.6
    private static let offWorkDuration = 4.0
    private static let unlockDuration = 2.8
    private static let stayHomeDuration = 3.2
    private static let swapDuration = 0.5
    private var noticeDuration: TimeInterval { noticeLookUp ? 1.6 : 0.9 }
    private static let lateNightDuration = 2.6
    private static let turnAwayDuration = 2.2
    private static let whistleDuration = 2.6
    private static let stretchUpDuration = 6.0
    private static let limberDuration = 4.6
    private static let doneDuration = 2.0
    private static let focusDoneDuration = 3.0

    /// Progress of a hummed note at `time` when 元气 is high: 2.4 s in every 16 s, or nil in between.
    nonisolated static func hum(at time: TimeInterval) -> Double? {
        let phase = time.truncatingRemainder(dividingBy: 16)
        guard phase >= 9, phase < 11.4 else { return nil }
        return (phase - 9) / 2.4
    }

    /// Progress of rubbing an eye at `time` when 元气 is low: 2.5 s in every 20 s, or nil in between and on
    /// boxing day.
    nonisolated static func rubEyes(at time: TimeInterval, mode: Mode) -> Double? {
        // Boxing gloves stay on, so a bare fist would be a third hand.
        guard mode != .boxing else { return nil }
        let phase = time.truncatingRemainder(dividingBy: 20)
        guard phase >= 14, phase < 16.5 else { return nil }
        return (phase - 14) / 2.5
    }
    /// How far back taps count towards pestering HAKU, in seconds.
    nonisolated static let pesterWindow: TimeInterval = 30

    /// Whether `taps` hold `count` or more taps within `pesterWindow` before `now`.
    nonisolated static func pestered(_ taps: [Date], now: Date, count: Int = 3) -> Bool {
        taps.filter { now.timeIntervalSince($0) < pesterWindow }.count >= count
    }

    /// The night to say "还不睡。" for when the app opens at `date`, or nil outside 0:00 to 5:00 or when it was
    /// already said that night. A night is named by the day of its evening, as `yyyy-MM-dd`.
    nonisolated static func newLateNight(at date: Date, last: String, calendar: Calendar = .current) -> String? {
        guard calendar.component(.hour, from: date) < 5,
            let evening = calendar.date(byAdding: .day, value: -1, to: date)
        else { return nil }
        let day = calendar.dateComponents([.year, .month, .day], from: evening)
        let night = String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
        return night == last ? nil : night
    }

    /// How long the app must have been closed for HAKU to look up with "oh, you're here", in seconds.
    nonisolated static let longAwayGap: TimeInterval = 12 * 3600

    /// Whether a notice that started at `start` is still playing at `now`.
    nonisolated static func noticePlaying(since start: Date?, now: Date, duration: TimeInterval) -> Bool {
        guard let start else { return false }
        return now.timeIntervalSince(start) < duration
    }

    /// Whether the app was closed for at least `longAwayGap` before `now`. False on the first launch.
    nonisolated static func backAfterLongAway(lastSeen: Double, now: Date) -> Bool {
        lastSeen > 0 && now.timeIntervalSinceReferenceDate - lastSeen >= longAwayGap
    }
    private static let rollDuration = 1.2
    /// How soon after rolling over a second tap half wakes a napping HAKU, in seconds.
    nonisolated static let napWakeWindow: TimeInterval = 8

    /// Whether a tap now half wakes a napping HAKU: only within `napWakeWindow` of the tap that rolled it over.
    nonisolated static func napWakes(lastTap: Date?, now: Date) -> Bool {
        guard let lastTap else { return false }
        return now.timeIntervalSince(lastTap) < napWakeWindow
    }

    /// The celebration id to play for `event`, or nil when there is none or it already played.
    nonisolated static func newCelebration(_ event: CompanionEvent?, last: String) -> String? {
        guard case .celebrate(let id, _) = event, id != last else { return nil }
        return id
    }

    /// The off-work day to play for `event`, or nil when there is none or it already played.
    nonisolated static func newOffWork(_ event: CompanionEvent?, last: String) -> String? {
        guard case .offWork(let day) = event, day != last else { return nil }
        return day
    }

    /// The unboxing id to play for `event`, or nil when there is none or it already played.
    nonisolated static func newUnlock(_ event: CompanionEvent?, last: String) -> String? {
        guard case .unlock(let id, _) = event, id != last else { return nil }
        return id
    }

    /// The staying-home day to play for `event`, or nil when there is none or it already played.
    nonisolated static func newStayHome(_ event: CompanionEvent?, last: String) -> String? {
        guard case .stayHome(let day) = event, day != last else { return nil }
        return day
    }

    /// The stand-up id to play for `event`, or nil when there is none or it already played.
    nonisolated static func newStretched(_ event: CompanionEvent?, last: String) -> String? {
        guard case .stretched(let id) = event, id != last else { return nil }
        return id
    }

    /// The id of getting up from the sofa to play for `event`, or nil when there is none or it already played.
    nonisolated static func newRevived(_ event: CompanionEvent?, last: String) -> String? {
        guard case .revived(let id) = event, id != last else { return nil }
        return id
    }

    /// The welcome back id to play for `event`, or nil when there is none or it already played.
    nonisolated static func newWelcome(_ event: CompanionEvent?, last: String) -> String? {
        guard case .welcomeBack(let id, _) = event, id != last else { return nil }
        return id
    }

    /// The planned task id to cheer for `event`, or nil when there is none or it already played.
    nonisolated static func newTaskDone(_ event: CompanionEvent?, last: String) -> String? {
        guard case .taskDone(let id, _) = event, id != last else { return nil }
        return id
    }

    private func playEventIfNew() {
        guard bedtime == .off else { return }
        if let id = Self.newCelebration(event, last: lastCelebration), case .celebrate(_, let kind) = event {
            lastCelebration = id
            celebrationKind = kind
            celebrationStart = .now
            say(CompanionLines.celebration(kind))
        }
        if let day = Self.newOffWork(event, last: lastOffWork) {
            lastOffWork = day
            offWorkStart = .now
            say(nil)
            bubbleTask = Task {
                try? await Task.sleep(for: .seconds(Self.offWorkDuration * 0.75))
                guard !Task.isCancelled else { return }
                say("终于。")
            }
        }
        if let id = Self.newUnlock(event, last: lastUnlock), case .unlock(_, let item) = event {
            lastUnlock = id
            unlockStart = .now
            say(nil)
            bubbleTask = Task {
                try? await Task.sleep(for: .seconds(Self.unlockDuration * 0.5))
                guard !Task.isCancelled else { return }
                say(CompanionLines.unlock(item), for: 4)
            }
        }
        if let day = Self.newStayHome(event, last: lastStayHome) {
            lastStayHome = day
            stayHomeStart = .now
            say(nil)
            bubbleTask = Task {
                try? await Task.sleep(for: .seconds(Self.stayHomeDuration * 0.65))
                guard !Task.isCancelled else { return }
                say("……今天在家？", for: 4)
            }
        }
        if let id = Self.newStretched(event, last: lastStretched) {
            lastStretched = id
            limberStart = .now
            say(nil)
            bubbleTask = Task {
                try? await Task.sleep(for: .seconds(Self.limberDuration * 0.52))
                guard !Task.isCancelled else { return }
                say("嗯，活过来了。", for: 3)
            }
        }
        if let id = Self.newRevived(event, last: lastRevived) {
            lastRevived = id
            reviveStart = .now
            say(nil)
            bubbleTask = Task {
                try? await Task.sleep(for: .seconds(Double(RunnerPose.reviveLine)))
                guard !Task.isCancelled else { return }
                say(Self.reviveLine, for: 2)
            }
        }
        if let id = Self.newWelcome(event, last: lastWelcome), case .welcomeBack(_, let replay) = event {
            lastWelcome = id
            startWelcome(replay)
        }
        if let id = Self.newTaskDone(event, last: lastTaskDone), case .taskDone(_, let focus) = event {
            lastTaskDone = id
            doneFocus = focus
            doneStart = .now
            say(nil)
            bubbleTask = Task {
                // The focus cheer says it after the fist pumps.
                try? await Task.sleep(for: .seconds(focus ? Self.focusDoneDuration * 0.9 : 0.3))
                guard !Task.isCancelled else { return }
                say("哦。弄完了？")
            }
        }
    }
    private static let notificationLoop = 2.4

    /// Plays the welcome back scene for `replay`, with its line, and calls `onWelcomeDone` as it ends.
    private func startWelcome(_ replay: ReturnReplay) {
        let scene = WelcomeScene(replay, mode: mode ?? .chill)
        welcomeReplay = replay
        welcomeStart = .now
        say(nil)
        bubbleTask = Task {
            try? await Task.sleep(for: .seconds(scene.line.at))
            guard !Task.isCancelled else { return }
            say(replay.line, for: scene.line.hold)
        }
        welcomeTask?.cancel()
        welcomeTask = Task {
            try? await Task.sleep(for: .seconds(Double(scene.length(cards: replay.cards.count, cans: replay.cans))))
            guard !Task.isCancelled else { return }
            endWelcome()
        }
    }

    /// Ends the welcome back scene, early on a tap, and tells the app.
    private func endWelcome() {
        guard welcomeStart != nil else { return }
        welcomeTask?.cancel()
        welcomeStart = nil
        welcomeReplay = nil
        say(nil)
        onWelcomeDone?()
    }

    /// Whether the good-night animation last played within the past 12 hours.
    nonisolated static func playedTonight(last: TimeInterval, now: Date) -> Bool {
        now.timeIntervalSinceReferenceDate - last < 12 * 60 * 60
    }

    private func startGoodnight() {
        goodnightStart = .now
        guard style != .notification else { return }
        lastGoodnight = Date.now.timeIntervalSinceReferenceDate
        bubbleTask?.cancel()
        bubbleTask = Task {
            try? await Task.sleep(for: .seconds(Self.goodnightDuration * 0.85))
            guard !Task.isCancelled else { return }
            say("该睡了")
        }
    }

    static let bathLine = "……去洗澡。我先占浴室了。"
    static let reviveLine = "……活过来了？"

    private func react() {
        if style == .watch {
            reactToPoke()
            return
        }
        if welcome(at: Date.now.timeIntervalSinceReferenceDate) != nil {
            // A tap skips the welcome back.
            endWelcome()
            return
        }
        if bath, dryStart == nil {
            dryStart = .now
            pop += 1
            say(nil)
            Task {
                try? await Task.sleep(for: .seconds(RunnerPose.bathDryLength))
                onBathDone?()
            }
            return
        }
        let life = mode.flatMap { idleLife($0, at: .now) }
        if bedtime == .off, life == .nap, !Self.napWakes(lastTap: rollStart, now: .now) {
            rollStart = .now
            say(nil)
            onTap?()
            return
        }
        rollStart = nil
        tapTimes = tapTimes.filter { Date.now.timeIntervalSince($0) < Self.pesterWindow } + [.now]
        if bedtime == .off, Self.pestered(tapTimes, now: .now) {
            tapTimes = []
            turnAwayStart = .now
            pop += 1
            say("……干嘛。")
            onTap?()
            return
        }
        pop += 1
        taps += 1
        whistleStart = bedtime == .off && (life == .snack || life == .drawing) ? .now : nil
        let peeking = couchStage(at: .now) == .peeking
        let lines = CompanionLines.lines(
            for: mode,
            need: shownNeed,
            peeking: peeking,
            life: life,
            activity: activity,
            moment: shownMoment
        )
        let candidates = lines.filter { $0 != bubble }
        say((candidates.isEmpty ? lines : candidates).randomElement())
        // Taps during a one-off animation only get HAKU's reaction.
        let time = Date.now.timeIntervalSinceReferenceDate
        guard celebration(at: time) == nil, taskDone(at: time) == nil, !stillOneOff(at: time) else { return }
        onTap?()
    }

    /// Plays the reaction to a poke on the watch with a light tap on the wrist; 5 pokes in a row turn HAKU away.
    private func reactToPoke() {
        guard let mode else { return }
        let now = Date.now
        pokes += 1
        guard turnAway(at: now.timeIntervalSinceReferenceDate) == nil else { return }
        tapTimes = tapTimes.filter { now.timeIntervalSince($0) < Self.pesterWindow } + [now]
        if Self.pestered(tapTimes, now: now, count: WatchPoke.tooMany) {
            tapTimes = []
            pokeKind = nil
            turnAwayStart = now
            pop += 1
            say(WatchPoke.tooManyLine)
            return
        }
        let life = idleLife(mode, at: now)
        let busy =
            shownNeed != nil || activity != nil || shownMoment != nil || life != nil || daily != nil
            || walking != nil || bath || invite != nil
        let kind = WatchPoke.pick(mode: mode, energy: energy, asleep: bedtime == .on || life == .nap, busy: busy)
        pokeKind = kind
        pokeStart = now
        if kind != .rollOver { pop += 1 }
        say(kind.line)
    }

    private func startInvite() {
        guard bedtime == .off, let invite else { return }
        pop += 1
        inviteJumps += 1
        say(invite, for: 5)
    }

    private func say(_ text: String?, for seconds: Double = 2.4) {
        bubbleTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { bubble = text }
        guard text != nil else { return }
        bubbleTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { bubble = nil }
        }
    }
}

// Made-up records for the previews.
private let previewWelcomes: [(String, Mode, ReturnReplay)] = {
    let cards = [
        ReturnCard(kind: .boxing, count: 2, text: "打了 2 次拳。"),
        ReturnCard(kind: .run5k, count: 1, text: "跑了 1 次 5 公里。"),
        ReturnCard(kind: .sleptWell, count: 3, text: "有几天睡得挺好。"),
        ReturnCard(kind: .trace, count: 1, item: CompanionTrace.runningShoes.rawValue, text: "门口多了双跑鞋。"),
        ReturnCard(kind: .keepsake, count: 1, item: "gloves.gold", text: "拿到了金拳套。"),
    ]
    return [
        ("preview-glance", .chill, ReturnReplay(tier: .glance, cards: Array(cards.prefix(3)), cans: 6)),
        ("preview-sofa", .chill, ReturnReplay(tier: .box, cards: cards, cans: 23)),
        ("preview-desk", .work, ReturnReplay(tier: .box, cards: cards, cans: 23)),
        ("preview-quiet", .chill, ReturnReplay(tier: .box, cards: [], cans: 0)),
    ]
}()

/// The squash and stretch as the character switches look.
struct Squash {
    var x: CGFloat = 1
    var y: CGFloat = 1
}

/// Lays the figure out for the watch's full-screen page: full width, 30 pt from the top, running off the bottom.
struct WatchFigureFrame: ViewModifier {
    let isEnabled: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if isEnabled {
            // The approved C layout shows him from the chest up, so the figure takes the whole width and the
            // screen edge crops the rest. The 12 pt side and 24 pt top padding of the card are undone here.
            GeometryReader { proxy in
                let width = proxy.size.width + 24
                content
                    .frame(width: width, height: width * 2, alignment: .top)
                    .offset(x: -12, y: 6)
            }
        } else {
            content
        }
    }
}

/// How `CompanionView` plays.
public enum CompanionStyle: Sendable {
    /// Home screen: the full good-night animation at bedtime, then the sleepy loop.
    case standard
    /// Notification content: a short bedtime loop.
    case notification
    /// Apple Watch app: a tap plays a poke reaction with a light tap on the wrist instead of a line.
    case watch
}

// Timings match the Rive build guide.
/// Per-mode idle loop.
struct IdleMotion {
    var dy: CGFloat
    var angle: Double

    /// Slumped on the couch: tilted back, barely breathing.
    static func slumped(time t: TimeInterval) -> IdleMotion {
        IdleMotion(dy: 4 + CGFloat(sin(t * 2 * .pi / 5)), angle: -3)
    }

    /// Two happy hops over a celebration; `progress` runs 0..<1.
    static func celebrating(progress: Double) -> IdleMotion {
        IdleMotion(dy: -CGFloat(abs(sin(progress * 2 * .pi))) * 22, angle: sin(progress * 4 * .pi) * 3)
    }

    /// The same motion with its bounce scaled by `factor`.
    func bouncing(_ factor: CGFloat) -> IdleMotion {
        IdleMotion(dy: dy * factor, angle: angle)
    }

    /// Slow breathing at bedtime, 4 s period.
    static func sleeping(time t: TimeInterval) -> IdleMotion {
        IdleMotion(dy: CGFloat(sin(t * 2 * .pi / 4)) * 1.5, angle: 0)
    }

    /// Rolling over in its sleep at `progress` (0..<1): a slow lean one way and back.
    static func rollingOver(time t: TimeInterval, progress: Double) -> IdleMotion {
        let breath = sleeping(time: t)
        return IdleMotion(dy: breath.dy + 2 * CGFloat(sin(progress * .pi)), angle: 8 * sin(progress * .pi))
    }

    init(dy: CGFloat, angle: Double) {
        self.dy = dy
        self.angle = angle
    }

    /// The idle loop for `moment`: walking bob, a slumped breath, or the mode's own loop.
    init(moment: CompanionMoment, mode: Mode, time t: TimeInterval) {
        switch moment {
        case .heading:
            // A step every 0.45 s, leaning into the walk.
            self.init(dy: -CGFloat(abs(sin(t * .pi / 0.45))) * 4, angle: 3)
        case .overtime:
            let breath = IdleMotion.sleeping(time: t)
            self.init(dy: breath.dy, angle: breath.angle)
        case .slacking:
            self.init(dy: 0, angle: 0)
        case .drowsy:
            self.init(dy: CGFloat(sin(t * 2 * .pi / 4)) * 1.5, angle: sin(t * 2 * .pi / 6) * 1.5)
        case .gymInvite:
            self.init(mode: .chill, time: t)
        case .vibeCoding, .flow, .lateCoding:
            self.init(mode: .work, time: t)
        case .shooting:
            self.init(mode: .money, time: t)
        case .collapsed, .blanket:
            let breath = IdleMotion.sleeping(time: t)
            self.init(dy: breath.dy, angle: breath.angle)
        case .morning:
            self.init(mode: .chill, time: t)
        case .timeToLeave:
            self.init(dy: -CGFloat(abs(sin(t * .pi / 0.5))) * 1.5, angle: 0)
        case .stiff:
            let sway = RunnerPose.stiffSway(at: t)
            self.init(dy: sway.dy, angle: sway.angle)
        case .packingUp:
            self.init(dy: 0, angle: 0)
        }
    }

    init(mode: Mode, time t: TimeInterval) {
        switch mode {
        case .work:
            // Slow nod to the music, every 0.5 s, very small.
            dy = CGFloat(abs(sin(t * .pi / 0.5))) * 3
            angle = 0
        case .chill:
            // Sway left and right, 3 s period.
            dy = 0
            angle = sin(t * 2 * .pi / 3) * 2.5
        case .boxing:
            // Small hop every 0.6 s.
            dy = -CGFloat(abs(sin(t * .pi / 0.6))) * 8
            angle = 0
        case .money:
            // Gentle float, 4 s period.
            dy = CGFloat(sin(t * 2 * .pi / 4)) * 5
            angle = sin(t * 2 * .pi / 8) * 1
        }
    }
}

struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Toy.body(15, weight: .bold))
            .foregroundStyle(Toy.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .toyCard(fill: Toy.card, radius: 12, shadow: 3)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(Mode.allCases) { mode in
                CompanionView(mode: mode).frame(height: 180).toyCard()
            }
            CompanionView(mode: .boxing, energy: 10).frame(height: 180).toyCard()
            CompanionView(mode: .money, energy: 85).frame(height: 180).toyCard()
            CompanionView(mode: .chill, need: .boxingWarmup).frame(height: 180).toyCard()
            CompanionView(mode: .chill, need: .couchScroll).frame(height: 180).toyCard()
            CompanionView(mode: .chill, need: .couchScroll, needSince: .now.addingTimeInterval(-45 * 60))
                .frame(height: 180)
                .toyCard()
            CompanionView(mode: .chill, need: .couchScroll, invite: "起来，下楼走 10 分钟？").frame(height: 180).toyCard()
            CompanionView(mode: .boxing, event: .celebrate(id: "preview", kind: .boxing)).frame(height: 180).toyCard()
            CompanionView(mode: .chill, event: .celebrate(id: "preview-run", kind: .running))
                .frame(height: 180)
                .toyCard()
            CompanionView(mode: .work, event: .offWork(id: "preview")).frame(height: 180).toyCard()
            CompanionView(mode: .chill, event: .stayHome(id: "preview")).frame(height: 180).toyCard()
            CompanionView(mode: .work, event: .stretched(id: "preview")).frame(height: 180).toyCard()
            CompanionView(mode: .money, event: .revived(id: "preview")).frame(height: 180).toyCard()
            ForEach(previewWelcomes, id: \.0) { welcome in
                CompanionView(mode: welcome.1, event: .welcomeBack(id: welcome.0, replay: welcome.2))
                    .frame(height: 340)
                    .toyCard()
            }
            ForEach(DailyProp.allCases, id: \.self) { prop in
                CompanionView(mode: .work, daily: DailyCue(stage: .soon, prop: prop, id: "preview-\(prop)"))
                    .frame(height: 180)
                    .toyCard()
            }
            CompanionView(mode: .chill, bath: true).frame(height: 180).toyCard()
            ForEach([HubPlace.Kind.home, .office, .fitness, .gym], id: \.self) { place in
                CompanionView(mode: place == .office ? .work : .chill, walking: place).frame(height: 180).toyCard()
            }
            ForEach([CommutePhase.Leg.toWork, .home], id: \.self) { leg in
                CompanionView(mode: .chill, commute: CommutePhase(leg: leg, stage: .walking, since: .now))
                    .frame(height: 180).toyCard()
            }
            ForEach(DailyScene.allCases, id: \.self) { scene in
                let cue = DailyCue(stage: .now, prop: .note, scene: scene, id: "preview-\(scene)")
                CompanionView(mode: .chill, daily: cue)
                    .frame(height: 180)
                    .toyCard()
            }
            CompanionView(mode: .work, daily: DailyCue(stage: .now, prop: .note, id: "preview-now"))
                .frame(height: 180)
                .toyCard()
            CompanionView(mode: .work, event: .taskDone(id: "preview", focus: false)).frame(height: 180).toyCard()
            CompanionView(mode: .work, event: .taskDone(id: "preview-focus", focus: true)).frame(height: 180).toyCard()
            CompanionView(
                mode: .boxing,
                event: .unlock(id: "preview", item: "gloves.gold"),
                wardrobe: Wardrobe(equipped: [.gloves: "gloves.gold"])
            )
            .frame(height: 180)
            .toyCard()
            ForEach(CompanionMoment.allCases, id: \.self) { moment in
                CompanionView(mode: .money, moment: moment, codingCans: 3).frame(height: 180).toyCard()
            }
            CompanionView(mode: .work, bedtime: .on).frame(height: 180).toyCard()
            CompanionView(mode: .chill, bedtime: .on, style: .notification, showsBubble: false)
                .frame(height: 180)
                .toyCard()
            ForEach(Mode.allCases) { mode in
                CompanionView(mode: mode, style: .watch)
                    .frame(width: 176, height: 194)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
            }
        }
        .padding()
    }
    .background(Toy.paper)
}
