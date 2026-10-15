import CompanionKit
import HubCore
import SwiftUI

struct HomeView: View {
    /// A setup problem from the app, shown with the store errors.
    var extraError: String?
    var bedtime: BedtimeSchedule = .standard
    var rules: ModeRules = .standard
    /// What RUNNER acts out now, from the iOS app's need tracker.
    var need: NeedReading?
    /// Where Mike is and his recent workouts, for what HAKU does alongside him; `nil` when unknown.
    var activitySignals: ActivitySignals?
    /// Recent workouts from the Health app, for today's traces.
    var workouts: [WorkoutSummary] = []
    /// Gym and run days.
    var activityDays: ActivityDays = .standard
    /// The last time Mike said he is going to the gym, from the iOS app.
    var departure: GymDeparture?
    /// A one-off animation for RUNNER, such as celebrating a workout.
    var event: CompanionEvent?
    /// What was recorded while Mike was away for days, played before any other event.
    var welcomeBack: CompanionEvent?
    /// Called once the welcome back scene ends or is skipped.
    var onWelcomeDone: (() -> Void)?
    /// The mode to show for a moment before the current one, so a switch made while the app was closed plays.
    var replayFrom: Mode?
    /// Today's invite text while its need lasts, so RUNNER gets up and says it.
    var invite: String?
    /// Whether Mike sat too long or just stood up, from the iOS app.
    var sit: SitState?
    /// Daily Widget's timed tasks, from the iOS app; `nil` while not linked.
    var daily: DailyPlan?
    /// The celebration for a Daily task just ticked done, from the iOS app.
    var dailyDone: CompanionEvent?
    /// HAKU's line on a day it stopped an invite Mike kept ignoring, from the iOS app.
    var notice: String?
    /// Which invites are paused, from the iOS app; RUNNER doesn't peek at the bag for a paused one.
    var backoff = NudgeBackoff()
    /// When each change moment happened, for HAKU's Sunday line.
    var changes: [Date] = []
    /// Shows a settings button that calls this, when set.
    var onSettings: (() -> Void)?
    /// Cans to spend; with `onShop`, shows the can count that opens the shop.
    var cans: Int?
    /// Opens the shop, when set.
    var onShop: (() -> Void)?
    /// Shows a house button that calls this, when set.
    var onHome: (() -> Void)?
    /// What the character wears.
    var wardrobe = Wardrobe()
    /// Which character the card draws.
    var persona = Persona.haku
    /// The name the greeting ends with, `nil` for none.
    var greetingName: String?
    /// The user's cards, for the mode names; `nil` uses the character's default cards.
    var cards: ModeCards?
    /// Earned cans, for the traces that stay.
    var ledger = CanLedger()
    /// Shows the wardrobe button on the companion card that calls this, when set.
    var onWardrobe: (() -> Void)?
    /// When Mike last tapped HAKU's bath away.
    var bathDoneAt: Date?
    /// The last Screen Time report of couch scrolling, from the iOS app.
    var scrollSeenAt: Date?
    /// How Mike moved since leaving home or the office, from the iOS app.
    var commuteMotion: [MotionSample] = []
    /// Start of the current stretch without walking, from the iOS app.
    var stillSince: Date?
    /// Records that Mike tapped HAKU's bath away.
    var onBathDone: (() -> Void)?
    /// Where the "不对" card records its answers; nil keeps no record.
    var decisionLogURL: URL?
    /// Debug screenshots: `open` shows the "不对" card, `reply` the reply after a correction.
    var screenshotCheck: String?

    @Environment(ModeStore.self) private var store
    @Environment(EnergyStore.self) private var energy
    @State private var cheer = 0
    // UI-27: the replay ends by itself, so the first frame after the app opens already shows the old mode.
    @State private var replayEnded = false
    /// Counts the user's own switches, so only they tap the phone.
    @State private var manualSwitches = 0
    /// The guess the "不对" card is asking about, while it is open.
    @State private var checking: EnergyReading?
    @State private var checkError: String?
    @State private var checkHeight: CGFloat = 0
    /// The character's short reply after an answer, shown for 1.6 s.
    @State private var checkReply: String?
    // Each answer to the energy check plays the character's nod under 「哦。」.
    @State private var nods = 0
    @State private var answers = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shownCards: ModeCards { cards ?? .legacy(for: persona) }

    var body: some View {
        let reading = energy.reading()
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Header(
                    mode: shownMode,
                    error: store.lastError ?? energy.lastError ?? extraError,
                    cans: cans,
                    onShop: onShop,
                    onHome: onHome,
                    onSettings: onSettings,
                    persona: persona,
                    name: greetingName,
                    cards: shownCards
                )

                // PRD section 15: the title shows here only, never on the Lock Screen.
                TimelineView(.everyMinute) { context in
                    if let next = daily?.next(after: context.date), let link = next.link {
                        Link(destination: link) {
                            HStack {
                                Text(DailyAgenda.nextLine(next, title: true, now: context.date))
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(Toy.body(15, weight: .heavy))
                            .foregroundStyle(Toy.ink)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .toyCard(radius: 12, shadow: 3)
                        }
                    }
                }

                TimelineView(.everyMinute) { context in
                    if persona == .kuro {
                        // Issue #164: her look per mode, energy face and bedtime; a tap shows a line for now.
                        KuroView(
                            look: KuroLook(mode: shownMode ?? .chill, card: shownCards.identity),
                            energy: reading?.value,
                            bedtime: bedtime.state(at: context.date),
                            need: activeNeed(at: context.date)?.need,
                            activity: shownActivity(at: context.date),
                            moment: moment(at: context.date),
                            overtimeUntil: rules.eveningUntil(at: context.date),
                            invite: activeNeed(at: context.date) == nil ? nil : invite,
                            walking: walking(at: context.date),
                            bath: bath(at: context.date),
                            wearing: wardrobe.worn(in: shownMode ?? .chill),
                            event: welcomeBack ?? event ?? revived(at: context.date)
                                ?? sit?.stretched(at: context.date)
                                ?? stayHome(at: context.date) ?? dailyDone,
                            cheer: cheer,
                            nods: nods,
                            onWelcomeDone: onWelcomeDone,
                            onBathDone: onBathDone
                        )
                    } else {
                        CompanionView(
                            mode: shownMode,
                            card: shownCards.identity,
                            energy: reading?.value,
                            need: activeNeed(at: context.date)?.need,
                            needSince: backoff.peekSince(activeNeed(at: context.date), at: context.date),
                            activity: shownActivity(at: context.date),
                            moment: moment(at: context.date),
                            codingCans: codingCans(at: context.date),
                            traces: traces(at: context.date, energy: reading?.level),
                            vitals: VitalsEngine.vitals(ledger: ledger, energy: energy.log, now: context.date),
                            event: welcomeBack ?? event ?? revived(at: context.date)
                                ?? sit?.stretched(at: context.date)
                                ?? stayHome(at: context.date) ?? dailyDone,
                            daily: daily?.cue(at: context.date),
                            walking: walking(at: context.date),
                            commute: inputs.commute(at: context.date),
                            bath: bath(at: context.date),
                            invite: activeNeed(at: context.date) == nil ? nil : invite,
                            cheer: cheer,
                            nods: nods,
                            bedtime: bedtime.state(at: context.date),
                            wardrobe: wardrobe,
                            onTap: tapAction,
                            onBathDone: onBathDone,
                            onWelcomeDone: onWelcomeDone
                        )
                    }
                }
                .frame(height: 340)
                .toyCard()
                .overlay(alignment: persona == .kuro ? .topLeading : .bottom) {
                    if let checkReply {
                        replyBubble(checkReply)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if let onWardrobe {
                        Button(action: onWardrobe) {
                            Label("衣柜", systemImage: "tshirt")
                                .font(Toy.body(15, weight: .heavy))
                                .foregroundStyle(Toy.ink)
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                                .background(Capsule().fill(Toy.card))
                                .overlay(Capsule().stroke(Toy.ink, lineWidth: Toy.outline))
                                .background(Capsule().fill(Toy.ink).offset(x: 3, y: 3))
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                    }
                }

                // Side-hustle states are HAKU's; KURO's desk time shows her tagline.
                if let state = store.sideHustle, persona == .haku {
                    Text("\(state.title) 中 · 点 \(persona.title) 换状态")
                        .font(Toy.body(16, weight: .bold))
                        .foregroundStyle(Toy.ink)
                } else if let mode = shownMode {
                    Text(shownCards.tagline(for: mode, persona: persona))
                        .font(Toy.body(16, weight: .bold))
                        .foregroundStyle(Toy.ink)
                } else {
                    // First launch, before any mode: the app's promise (PRD §18).
                    Text("你认真活过的每一天，都不该白白消失。")
                        .font(Toy.body(16, weight: .bold))
                        .foregroundStyle(Toy.ink)
                }

                // UI 审核 2026-10-13: energy sits close under the tagline, not like a caption for the cards.
                VStack(alignment: .leading, spacing: 4) {
                    // Why RUNNER looks this way: leaving work, the activity, bedtime, then the need, then energy.
                    TimelineView(.everyMinute) { context in
                        let state = bedtime.state(at: context.date)
                        let active = activeNeed(at: context.date)
                        // Energy has its own row below, so it never hides behind another line.
                        let why = NeedEngine.whyLine(need: active, energy: nil, bedtime: state)
                        let workLine = moment(at: context.date).flatMap(HakuLines.scene(for:)).map {
                            HakuLines.line($0, at: context.date, persona: persona, cards: shownCards)
                        }
                        let sunday = ChangeEngine.sundayLine(times: changes, now: context.date)
                        let leftWork = HakuLines.offWorkUntil(store.log, now: context.date, work: rules)
                        let offWork = leftWork.map { HakuLines.offWorkLine(for: persona, until: $0, work: rules) }
                        let activityLine = activity(at: context.date)?.reason(for: persona)
                        if let line = offWork ?? activityLine ?? workLine ?? notice ?? sunday ?? why {
                            Text(line)
                                .font(Toy.body(13, weight: .bold))
                                .foregroundStyle(Toy.muted)
                        }
                    }

                    energyRow(reading)
                }
                .padding(.top, -12)

                ModeSwitcher(current: shownMode, persona: persona, cards: shownCards) { mode in
                    switchTo(mode)
                }
                .anchorPreference(key: SwitcherBounds.self, value: .bounds) { $0 }

                TimelineView(.periodic(from: .now, by: 60)) { context in
                    TodayTimeline(
                        segments: store.segments(on: context.date, now: context.date),
                        persona: persona,
                        cards: shownCards
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Toy.paper.ignoresSafeArea())
        .overlayPreferenceValue(SwitcherBounds.self) { anchor in
            GeometryReader { proxy in
                checkCard(
                    switcher: anchor.map { proxy[$0] },
                    height: proxy.size.height,
                    bottomInset: proxy.safeAreaInsets.bottom
                )
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: answers)
        .modeSwitchHaptic(trigger: manualSwitches)
        // HAKU starts in the old mode, then switches, so the switch animation plays.
        .task {
            guard let screenshotCheck else { return }
            // After ScreenshotHome has set today's energy.
            try? await Task.sleep(for: .seconds(1))
            guard let reading = energy.reading(), reading.source != .selfReport else { return }
            switch screenshotCheck {
            case "reply":
                checkReply = EnergyCheck.reply(corrected: true, persona: persona)
            case "hold":
                // Waits for a real tap on 不对？, from Apps/UITests.
                break
            default:
                checking = reading
            }
        }
        .task(id: replayFrom) {
            guard replayFrom != nil else { return }
            try? await Task.sleep(for: .seconds(1.2))
            replayEnded = true
        }
        // Each new replay starts unfinished, also when one follows another without a nil in between.
        .onChange(of: replayFrom) {
            replayEnded = false
        }
    }

    /// The "不对" card over a dimmed layer that closes it on a tap.
    @ViewBuilder private func checkCard(switcher: CGRect?, height: CGFloat, bottomInset: CGFloat) -> some View {
        if let checking {
            let place = checkPlace(switcher: switcher, height: height, bottomInset: bottomInset)
            ZStack(alignment: .top) {
                // Dims the whole home screen, so what the card overlaps reads as behind it.
                Toy.ink.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture { closeCheck() }
                EnergyCheckCard(guess: checking, persona: persona, error: checkError, fill: place.fill) {
                    answer($0, to: checking)
                }
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.height
                } action: {
                    // Only the card's own height; a stretched card would move it back and forth.
                    if place.fill == 0 { checkHeight = $0 }
                }
                .padding(.horizontal, 20)
                .offset(y: place.top)
                .gesture(
                    DragGesture(minimumDistance: 10).onEnded { drag in
                        if drag.translation.height > 40 { closeCheck() }
                    }
                )
            }
            .transition(reduceMotion ? .identity : .opacity)
        }
    }

    // UI 审核 F10 and round 3: the card's edges fall only in the gaps between blocks. Its top sits 12 pt under
    // the first row of mode buttons and it reaches past the bottom of the screen, covering what is below.
    // When those buttons are off screen it sits at the bottom at its own height.
    /// Where the card's top edge goes in a space `height` tall, and the least height that reaches past its bottom.
    private func checkPlace(
        switcher: CGRect?,
        height: CGFloat,
        bottomInset: CGFloat
    ) -> (top: CGFloat, fill: CGFloat) {
        if let switcher {
            // Two rows of buttons 14 pt apart on iPhone.
            let firstRow = switcher.height > 120 ? (switcher.height - 14) / 2 : switcher.height
            let top = switcher.minY + firstRow + 12
            if top >= 0, top + checkHeight + 24 <= height {
                return (top, height + bottomInset + 24 - top)
            }
        }
        return (height - 24 - checkHeight, 0)
    }

    /// Where today's energy comes from. Only a guess from sleep can be corrected, from its 不对？ button.
    // 干预策略 §6 (2026-10-13): Mike found no card behind the long press, so the entry moved here.
    // UI 审核 2026-10-13: the whole row is the tap target, and it is 44 pt tall with or without the button,
    // so the cards below never jump.
    @ViewBuilder private func energyRow(_ reading: EnergyReading?) -> some View {
        let text = Text(reading?.reasons.first ?? "今天没有睡眠数据")
            .font(Toy.body(13, weight: .bold))
            .foregroundStyle(Toy.muted)
        if let reading, reading.source != .selfReport {
            Button {
                checkError = nil
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { checking = reading }
            } label: {
                HStack(spacing: 8) {
                    text
                    // The rounded font draws a narrow question mark, so the full-width one uses the system font.
                    HStack(spacing: 0) {
                        Text("不对").font(Toy.body(12, weight: .heavy))
                        Text("？").font(.system(size: 12, weight: .heavy))
                    }
                    .foregroundStyle(Toy.ink)
                    // The full-width ？ carries half a character of space on its right, so that side pads less.
                    .padding(.leading, 10)
                    .padding(.trailing, 4)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Toy.card))
                    .overlay(Capsule().stroke(Toy.ink, lineWidth: 2))
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44, alignment: .top)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("不对？"))
        } else {
            text.frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
        }
    }

    // KURO holds things low in front of her, so her bubble sits above her head with its tail pointing down to her.
    /// The character's one-line reply after an answer.
    @ViewBuilder private func replyBubble(_ text: String) -> some View {
        let bubble = Text(text)
            .font(Toy.body(16, weight: .heavy))
            .foregroundStyle(Toy.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        if persona == .kuro {
            // The tail's fill covers the bubble's bottom edge, so the two read as one outline.
            bubble
                .toyCard(radius: 14, shadow: 3)
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        BubbleTail(closed: true).fill(Toy.card)
                        BubbleTail(closed: false)
                            .stroke(Toy.ink, style: StrokeStyle(lineWidth: Toy.outline, lineJoin: .round))
                    }
                    .frame(width: 16, height: 14)
                    .offset(x: -14, y: 14 - Toy.outline)
                }
                .padding(.top, 28)
                .padding(.leading, 24)
        } else {
            bubble
                .toyCard(radius: 14, shadow: 3)
                .padding(.bottom, 16)
        }
    }

    /// Records `choice` for `guess`, closes the card and shows the character's reply for 1.6 s.
    private func answer(_ choice: EnergyAnswer, to guess: EnergyReading) {
        answers += 1
        let result = EnergyCheck.answer(choice, to: guess, energy: energy, decisionLogURL: decisionLogURL)
        // An error keeps the card open, with the message where the question was.
        if let error = result.error {
            checkError = error
            return
        }
        closeCheck()
        let reply = EnergyCheck.reply(corrected: result.report != nil, persona: persona)
        checkReply = reply
        nods += 1
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if checkReply == reply { checkReply = nil }
        }
    }

    // Closing without an answer records nothing.
    private func closeCheck() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { checking = nil }
        checkError = nil
    }

    // The scene rules live in HubCore, so the watch plays the same scene as this card.
    private var inputs: HomeSceneInputs {
        HomeSceneInputs(
            log: store.log,
            rules: rules,
            bedtime: bedtime,
            need: need,
            signals: activitySignals,
            days: activityDays,
            departure: departure,
            sit: sit,
            bathDoneAt: bathDoneAt,
            scrollSeenAt: scrollSeenAt,
            daily: daily,
            invite: invite,
            motion: commuteMotion,
            stillSince: stillSince
        )
    }

    private func activeNeed(at date: Date) -> NeedReading? { inputs.activeNeed(at: date) }

    private func moment(at date: Date) -> CompanionMoment? { inputs.moment(at: date) }

    private func stayHome(at date: Date) -> CompanionEvent? { inputs.stayHome(at: date) }

    private func shownActivity(at date: Date) -> CompanionActivity? { inputs.shownActivity(at: date) }

    private func revived(at date: Date) -> CompanionEvent? { inputs.revived(at: date) }

    private func walking(at date: Date) -> HubPlace.Kind? { inputs.walking(at: date) }

    private func bath(at date: Date) -> Bool { inputs.bath(at: date) }

    private func activity(at date: Date) -> CompanionActivity? { inputs.activity(at: date) }

    private func traces(at date: Date, energy: EnergyLevel?) -> Set<CompanionTrace> {
        let today = MomentEngine.traces(log: store.log, workouts: workouts, energy: energy, now: date)
        return today.union(MomentEngine.lastingTraces(log: store.log, ledger: ledger, now: date))
    }

    private func codingCans(at date: Date) -> Int { inputs.codingCans(at: date) }

    // In 副业 a tap switches the state. It is manual, so it earns nothing and holds automatic switches.
    // With only one state picked there is nothing to switch to, so the tap gets the usual reaction.
    private var tapAction: (() -> Void)? {
        guard let state = store.sideHustle, shownCards.next(after: state) != state else { return nil }
        return {
            withAnimation(.easeInOut(duration: 0.2)) {
                _ = store.cycleSideHustle(cards: shownCards)
            }
        }
    }

    // UI-27: the character, header and mode buttons change in the same frame.
    /// The mode shown: the one before a switch made while the app was closed, until its replay ends.
    private var shownMode: Mode? {
        guard let replayFrom, !replayEnded else { return store.current }
        return replayFrom
    }

    private func switchTo(_ mode: Mode) {
        let changed = withAnimation(.easeInOut(duration: 0.2)) {
            // 副业 starts in the user's first picked state.
            store.switchTo(mode, tag: mode == .money ? shownCards.sideStates[0].rawValue : nil)
        }
        // A tap during the replay ends it, so the buttons show what was tapped.
        replayEnded = true
        if changed { manualSwitches += 1 }
        // Boxing day gets a pep jump on entry.
        if changed, mode == .boxing { cheer += 1 }
    }
}

extension View {
    /// A tap on iPhone each time `trigger` changes; nothing on Mac.
    @ViewBuilder func modeSwitchHaptic(trigger: Int) -> some View {
        #if os(iOS)
        sensoryFeedback(.impact(weight: .medium), trigger: trigger)
        #else
        self
        #endif
    }
}

private struct Header: View {
    let mode: Mode?
    let error: String?
    let cans: Int?
    let onShop: (() -> Void)?
    let onHome: (() -> Void)?
    let onSettings: (() -> Void)?
    let persona: Persona
    let name: String?
    let cards: ModeCards

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // The badges and buttons share a row with the date, so the greeting keeps the full width.
            HStack(alignment: .center) {
                subtitle
                    .font(Toy.body(13, weight: .bold))
                    .foregroundStyle(Toy.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
                if let badge = AppEnvironment.badge {
                    Text(badge)
                        .font(Toy.body(11, weight: .heavy))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Toy.pink))
                        .overlay(Capsule().stroke(Toy.ink, lineWidth: 2))
                        .foregroundStyle(Toy.ink)
                }
                if let cans, let onShop {
                    Button(action: onShop) {
                        CanChip(count: cans)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("商店，\(cans) 个能量罐")
                }
                if let onHome {
                    Button(action: onHome) {
                        Image(systemName: "house.fill")
                            .font(Toy.body(18, weight: .heavy))
                            .foregroundStyle(Toy.ink)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("家")
                }
                if let onSettings {
                    Button(action: onSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(Toy.body(18, weight: .heavy))
                            .foregroundStyle(Toy.ink)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("设置")
                }
            }
            Text(greeting)
                .font(Toy.display(26))
                .foregroundStyle(Toy.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let error {
                ErrorLine(text: error)
            }
        }
    }

    private var greeting: String {
        Greeting.text(hour: Calendar.current.component(.hour, from: .now), name: name)
    }

    // UI 二组 preview 6: a new user has no mode yet, and says so in words, not in a code.
    private var subtitle: Text {
        let date = Date.now.formatted(.dateTime.month().day().weekday(.wide))
        guard let mode else { return Text("\(date) · 还没有模式") }
        return Text(verbatim: "\(date) · \(cards.code(for: mode, persona: persona)) MODE")
    }
}

#Preview {
    HomeView()
        .environment(ModeStore.preview())
        .environment(EnergyStore(fileURL: nil, deviceID: "preview"))
}

/// A speech-bubble tail: a right triangle whose point is at the bottom trailing corner.
private struct BubbleTail: Shape {
    /// Whether the path includes the top edge, which joins the bubble.
    var closed: Bool

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            if closed { path.closeSubpath() }
        }
    }
}

/// The mode buttons' frame, so the "不对" card can line up with their rows.
private struct SwitcherBounds: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}
