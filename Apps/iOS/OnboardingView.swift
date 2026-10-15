import CompanionKit
import CoreLocation
import HealthKit
import HubCore
import SwiftUI
import UserNotifications

// Issue #273, onboarding preview v6 (UI 二组). Copy from 03 Product/onboarding 文案 v0. Each answer goes into the
// draft, which is saved after every change, so leaving halfway picks up at the same screen.
/// The first-run setup: character, Chill activities, identity card, bedtime, work days, places, 副业 and
/// permissions, ending with the cards the answers make.
struct OnboardingView: View {
    @Binding var places: PlaceSettings
    let monitor: PlaceMonitor
    /// Called with the finished draft after the last screen or after 用默认.
    let onDone: (OnboardingDraft) -> Void

    @State private var draft = OnboardingDraft.stored(in: AppGroup.defaults)
    @State private var picked: Persona?
    @State private var history: [OnboardingDraft.Step] = []
    @State private var asksDefaults = false
    @State private var bedMinute = 0
    @State private var work = OnboardingDraft.Work.shown
    @State private var irregular = false
    @State private var movedFitness = false
    @State private var sideFull = 0
    @State private var location = CLLocationManager().authorizationStatus
    @State private var locating: String?
    @State private var later: Set<String> = []
    @State private var error: String?
    @FocusState private var naming: Mode?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            screen
                .id(draft.step)
                .transition(
                    reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity)
                )
            if asksDefaults {
                ToyConfirmSheet(
                    question: "先用默认的？",
                    warning: "先给你 上班、下班、副业 三张卡，没有身份卡。睡觉时间、上班日算没设，不出相关提醒。都能在 设置 > 模式 里补。",
                    cancel: "回去说说",
                    confirm: "用默认",
                    confirmFill: Toy.pink,
                    confirmText: Toy.ink,
                    onCancel: { asksDefaults = false },
                    onConfirm: { onDone(draft) }
                )
            }
        }
        .foregroundStyle(Toy.ink)
        .background(Toy.paper.ignoresSafeArea())
        .onChange(of: draft) { draft.store(in: AppGroup.defaults) }
    }

    // MARK: - Screens

    @ViewBuilder private var screen: some View {
        switch draft.step {
        case .persona: personaScreen
        case .intro: introScreen
        case .chill: chillScreen
        case .identity: identityScreen
        case .bedtime: bedtimeScreen
        case .work: workScreen
        case .location:
            askScreen(dot: 5, line: line(.location), note: "选「始终允许」，它才能在你没打开 App 时也跟着换。位置只留在这台手机里。") {
                let allowed = await OnboardingAccess.location()
                location = CLLocationManager().authorizationStatus
                draft.allowsLocation = allowed
            } onLater: {
                draft.allowsLocation = false
            }
        case .places: placesScreen
        case .motion:
            askScreen(dot: 5, line: line(.motion), note: "只在手机上分辨走路 / 坐车，不上传。") {
                await OnboardingAccess.motion()
            }
        case .sideHustle: sideScreen
        case .health:
            askScreen(dot: 7, line: line(.health), note: "只读睡眠和运动记录，不上传。") {
                await OnboardingAccess.health()
            }
        case .cards: cardsScreen
        case .notifications, .done:
            askScreen(dot: 8, line: line(.notifications), note: nil, later: "不用", skips: false) {
                await OnboardingAccess.notifications()
            }
        }
    }

    private var personaScreen: some View {
        page(dot: nil, back: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text("选一个住进你手机的家伙").font(Toy.display(26))
                Text("以后可以换，各自的东西分开存。").font(Toy.body(14, weight: .bold)).foregroundStyle(Toy.muted)
            }
            HStack(spacing: 14) {
                personaCard(.haku, line: "嘴硬的室友，其实什么都记得")
                personaCard(.kuro, line: "安静，会在旁边陪着")
            }
        } foot: {
            primary(picked == nil ? "先选一个" : "就它了", enabled: picked != nil) {
                draft.persona = picked ?? .haku
                next()
            }
        } onSkip: {
            draft.persona = .haku
            next()
        }
    }

    private var introScreen: some View {
        page(dot: nil, back: true, skips: false) {
            figure(.chill, width: 220)
                .frame(maxWidth: .infinity)
            Text(line(.intro)).font(Toy.display(26))
        } foot: {
            primary("告诉它") { next() }
            textButton("跳过，直接开始") { asksDefaults = true }
        }
    }

    private var chillScreen: some View {
        page(dot: 1) {
            hero(line(.chill), sub: "勾常做的，不勾也行。")
            LazyVGrid(columns: Self.columns, spacing: 12) {
                chip("在家休息", detail: "默认，不能取消", symbol: "sofa.fill", isOn: true, fill: chillColor, locked: true) {}
                ForEach(ChillActivity.allCases, id: \.self) { activity in
                    let isOn = draft.chill?.contains(activity) ?? false
                    chip(activity.title, detail: activity.source, symbol: activity.symbol, isOn: isOn, fill: chillColor)
                    {
                        draft.chill = (draft.chill ?? []).symmetricDifference([activity])
                    }
                }
            }
            fine("戴着手表做的运动它会自己知道。")
        } foot: {
            primary("下一步") {
                if draft.chill == nil { draft.chill = [] }
                next()
            }
        } onSkip: {
            draft.chill = nil
            next()
        }
    }

    private var identityScreen: some View {
        page(dot: 2) {
            hero(
                draft.identity == nil ? line(.identity) : line(.identityPicked),
                sub: draft.identity == nil ? "选一张，或者「现在没有」。" : "",
                mode: shownLook
            )
            LazyVGrid(columns: Self.columns, spacing: 12) {
                ForEach(IdentityKind.released, id: \.self) { kind in
                    identityTile(kind)
                }
            }
            if draft.identity != nil {
                note("hand.tap.fill", "没设地点的话，到时候点一下这张卡就切过去；戴手表做完运动，它也会知道。")
            }
            if movedFitness {
                note("dumbbell.fill", "「健身」从下班里拿出来，放进这张卡了。一件事只放一张卡。")
            }
        } foot: {
            if draft.identity == nil {
                secondary("现在没有") { next() }
            } else {
                primary("就它了") { next() }
            }
        } onSkip: {
            draft.identity = nil
            next()
        }
    }

    private var bedtimeScreen: some View {
        page(dot: 3) {
            hero(line(.bedtime), sub: "只用来定提醒，不记你几点睡着。")
            DatePicker("睡觉时间", selection: minuteBinding($bedMinute), displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .padding(12)
                .toyCard()
        } foot: {
            primary("下一步") {
                draft.bedtime = BedtimeSchedule(startMinute: bedMinute, endMinute: BedtimeSchedule.standard.endMinute)
                next()
            }
        } onSkip: {
            draft.bedtime = nil
            next()
        }
    }

    private var workScreen: some View {
        page(dot: 4) {
            hero(
                irregular ? line(.irregular) : line(.work),
                sub: irregular ? "" : "默认周一到周五，\(clock(9 * 60)) 到 \(clock(18 * 60))。")
            if !irregular {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 4) {
                        let week = Languages.weekCalendar()
                        ForEach(week.weekdaysInOrder, id: \.self) { day in
                            dayButton(day, in: week)
                        }
                    }
                    HStack {
                        DatePicker(
                            "上班", selection: minuteBinding($work.startMinute), displayedComponents: .hourAndMinute)
                        Text("到").font(Toy.body(15, weight: .heavy))
                        DatePicker("下班", selection: minuteBinding($work.endMinute), displayedComponents: .hourAndMinute)
                    }
                    .labelsHidden()
                    fine("下班前 15 分钟提醒一次，只在你上班的日子。")
                }
                .padding(16)
                .toyCard()
            } else {
                fine("不固定的话，上班只靠到了上班的地方来切，也不发下班提醒。")
            }
            Toggle("不固定", isOn: $irregular.animation(.easeOut(duration: 0.2)))
                .font(Toy.body(16, weight: .heavy))
                .tint(workColor)
                .padding(16)
                .toyCard()
        } foot: {
            primary("下一步") {
                draft.work = irregular ? .irregular : work
                next()
            }
        } onSkip: {
            draft.work = nil
            next()
        }
    }

    private var placesScreen: some View {
        page(dot: 5) {
            hero(line(.places), sub: "人在哪儿就点哪儿。没有地图，位置只存在这台手机上。")
            switch location {
            case .denied, .restricted, .notDetermined:
                settingsLine("没有位置权限，到了地方不会自动换。", link: "去设置打开")
            case .authorizedWhenInUse:
                settingsLine("只在打开 App 时认得出。要自动换，去设置改成「始终」。", link: "去设置")
            default:
                EmptyView()
            }
            ForEach(placeRows, id: \.id) { row in
                placeRow(row)
            }
            if let error {
                ErrorLine(text: error, size: 13)
            }
            fine("第一次到一个新地方时，也可以在首页点一下「设为……」。")
        } foot: {
            primary("下一步") { next() }
        } onSkip: {
            next()
        }
        .onAppear { location = CLLocationManager().authorizationStatus }
    }

    private var sideScreen: some View {
        let states = draft.sideStates ?? []
        return page(dot: 6) {
            hero(line(.sideHustle), sub: "最多选 \(ModeCards.sideStateLimit) 个。")
            Text("\(states.count) / \(ModeCards.sideStateLimit)")
                .font(Toy.body(14, weight: .black))
                .frame(maxWidth: .infinity, alignment: .trailing)
            LazyVGrid(columns: Self.columns, spacing: 12) {
                ForEach(Self.sideStates, id: \.self) { state in
                    chip(
                        state.title,
                        detail: nil,
                        symbol: state.symbol,
                        isOn: states.contains(state),
                        fill: Mode.money.color(for: draft.persona)
                    ) {
                        toggle(state)
                    }
                }
            }
            if sideFull > 0 {
                ErrorLine(text: "最多 \(ModeCards.sideStateLimit) 个，先去掉一个。", size: 13)
            }
            fine("进了副业以后，点它就能换成另一件。")
        } foot: {
            primary("下一步", enabled: !states.isEmpty) { next() }
            // PM 2026-10-13: the 副业 card always stays; 先不选 keeps the default 做项目.
            textButton("先不选") { skipSide() }
        } onSkip: {
            skipSide()
        }
        .onAppear {
            if draft.sideStates == nil { draft.sideStates = [.project] }
        }
    }

    private var cardsScreen: some View {
        let cards = draft.cards
        return page(dot: 8, skips: false) {
            hero(line(.cards), sub: "", figureWidth: 64)
            Text(cards.modes.count == 4 ? "你的四张卡" : "你的三张卡")
                .font(Toy.display(20))
            ForEach(cards.modes, id: \.self) { mode in
                modeCard(mode, cards: cards)
            }
            fine("之后都能在设置里改。")
        } foot: {
            if naming == nil {
                primary("下一步") { next() }
            }
        }
    }

    // MARK: - Pieces

    private func askScreen(
        dot: Int,
        line: String,
        note: String?,
        later: String = "以后再说",
        skips: Bool = true,
        onYes: @escaping @MainActor () async -> Void,
        onLater: @escaping () -> Void = {}
    ) -> some View {
        page(dot: dot, skips: skips) {
            figure(.chill, width: 190)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                Text(line).font(Toy.display(20))
                if let note {
                    Text(note).font(Toy.body(14, weight: .bold)).foregroundStyle(Toy.muted)
                }
            }
        } foot: {
            primary("好") {
                Task {
                    await onYes()
                    next()
                }
            }
            textButton(later) {
                onLater()
                next()
            }
        } onSkip: {
            onLater()
            next()
        }
    }

    // The progress dots count the preview's 8 steps; location, places and motion share step 5.
    private func page<Content: View, Foot: View>(
        dot: Int?,
        back: Bool = true,
        skips: Bool = true,
        @ViewBuilder content: () -> Content,
        @ViewBuilder foot: () -> Foot,
        onSkip: (() -> Void)? = nil
    ) -> some View {
        let main = content()
        let bottom = foot()
        return VStack(spacing: 0) {
            HStack {
                if back, !history.isEmpty {
                    Button(action: goBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .heavy))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("上一步")
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
                Spacer()
                if let dot {
                    dots(dot)
                }
                Spacer()
                if skips, let onSkip {
                    Button("跳过", action: onSkip)
                        .font(Toy.body(15, weight: .heavy))
                        .frame(minWidth: 44, minHeight: 44)
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) { main }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 6) { bottom }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 12)
                    .background(
                        LinearGradient(
                            stops: [
                                .init(color: Toy.paper.opacity(0), location: 0), .init(color: Toy.paper, location: 0.3),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }

    private func dots(_ step: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(1...8, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Toy.ink : Toy.card)
                    .overlay(Capsule().stroke(Toy.ink, lineWidth: 2))
                    .frame(width: 22, height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("第 \(step) 步，共 8 步")
    }

    private func hero(_ text: String, sub: String, mode: Mode = .chill, figureWidth: CGFloat = 92) -> some View {
        HStack(alignment: .top, spacing: 14) {
            figure(mode, width: figureWidth)
            VStack(alignment: .leading, spacing: 4) {
                Text(text).font(Toy.display(20))
                if !sub.isEmpty {
                    Text(sub).font(Toy.body(14, weight: .bold)).foregroundStyle(Toy.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .toyCard(radius: 18, shadow: 4)
            .padding(.top, 8)
        }
        .animation(.easeOut(duration: 0.25), value: text)
    }

    // The character idles as on the home card; no new motion here.
    @ViewBuilder private func figure(_ mode: Mode, width: CGFloat) -> some View {
        Group {
            if draft.persona == .kuro {
                KuroView(look: KuroLook(mode: mode), showsBubble: false)
            } else {
                CompanionView(mode: mode, showsBubble: false, notices: false)
            }
        }
        .frame(width: width, height: (width * 1.32).rounded())
        .toyCard(fill: mode.color(for: draft.persona), radius: width > 120 ? 22 : 14, shadow: width > 120 ? 5 : 4)
        .accessibilityHidden(true)
    }

    private func personaCard(_ persona: Persona, line: String) -> some View {
        let isOn = picked == persona
        return Button {
            picked = persona
            draft.persona = persona
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Group {
                    if persona == .kuro {
                        KuroView(look: .chill, showsBubble: false)
                    } else {
                        CompanionView(mode: .chill, showsBubble: false, notices: false)
                    }
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .background(Mode.chill.color(for: persona))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(persona.title).font(Toy.display(20))
                Text(line).font(Toy.body(12, weight: .bold)).foregroundStyle(Toy.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .toyCard(fill: isOn ? Toy.pink : Toy.card, radius: 18, shadow: isOn ? 1 : 4)
            .offset(x: isOn ? 3 : 0, y: isOn ? 3 : 0)
            .overlay(alignment: .topTrailing) { if isOn { tick } }
            .animation(.easeOut(duration: 0.18), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func chip(
        _ title: String,
        detail: String?,
        symbol: String,
        isOn: Bool,
        fill: Color,
        locked: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(Toy.body(15, weight: .heavy))
                    if let detail {
                        Text(detail).font(Toy.body(11, weight: .bold)).foregroundStyle(isOn ? Toy.ink : Toy.muted)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 56)
            .toyCard(fill: isOn ? fill : Toy.card, radius: 14, shadow: isOn ? 1 : 4)
            .offset(x: isOn ? 3 : 0, y: isOn ? 3 : 0)
            .overlay(alignment: .topTrailing) {
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(fill)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Toy.ink))
                        .offset(x: 6, y: -4)
                } else if isOn {
                    tick
                }
            }
            .animation(.easeOut(duration: 0.12), value: isOn)
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var tick: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(Toy.card)
            .frame(width: 22, height: 22)
            .background(Circle().fill(Toy.ink))
            .offset(x: 6, y: -4)
    }

    private func identityTile(_ kind: IdentityKind) -> some View {
        let isOn = draft.identity == kind
        return Button {
            pick(kind)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: kind.symbol).font(.system(size: 26, weight: .bold))
                Text(kind.title).font(Toy.display(20)).padding(.top, 4)
                Text(kind.howItSwitches).font(Toy.body(11, weight: .bold)).foregroundStyle(isOn ? Toy.ink : Toy.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .padding(12)
            .toyCard(fill: isOn ? Mode.boxing.color(for: draft.persona) : Toy.card, radius: 16, shadow: isOn ? 1 : 4)
            .offset(x: isOn ? 3 : 0, y: isOn ? 3 : 0)
            .overlay(alignment: .topTrailing) { if isOn { tick } }
            .animation(.easeOut(duration: 0.12), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func dayButton(_ day: Int, in week: Calendar) -> some View {
        let isOn = work.workdays.contains(day)
        return Button {
            work.workdays = work.workdays.symmetricDifference([day])
        } label: {
            Text(week.veryShortWeekdaySymbols[day - 1])
                .font(Toy.body(15, weight: .black))
                // Seven columns share the card's width; the circle is 40 pt or the column, whichever is less.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 40)
                .background(Circle().fill(isOn ? workColor : Toy.card))
                .overlay(Circle().stroke(Toy.ink, lineWidth: 2.5))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .animation(.easeOut(duration: 0.12), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(week.standaloneWeekdaySymbols[day - 1])
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func placeRow(_ row: PlaceRow) -> some View {
        let isSet = places.places.contains { $0.id == row.id }
        let canSet = location == .authorizedAlways || location == .authorizedWhenInUse
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: row.symbol)
                .font(.system(size: 20, weight: .bold))
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 6) {
                Text(row.title).font(Toy.body(16, weight: .heavy))
                if isSet {
                    fine("范围 \(Int(HubPlace.defaultRadius)) 米")
                } else if !canSet {
                    fine("有了位置权限才能设。")
                } else if locating == row.id {
                    fine("定位中…")
                } else if later.contains(row.id) {
                    fine("到了再说。")
                } else {
                    HStack(spacing: 8) {
                        pill("现在就在这儿", symbol: "mappin") { Task { await setHere(row) } }
                        pill("到了再说", symbol: nil) { later.insert(row.id) }
                    }
                }
            }
            Spacer(minLength: 0)
            if isSet {
                Label("设好了", systemImage: "checkmark")
                    .font(Toy.body(12, weight: .black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(chillColor))
                    .overlay(Capsule().stroke(Toy.ink, lineWidth: 2))
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .toyCard(radius: 16, shadow: 4)
        .animation(.easeOut(duration: 0.25), value: isSet)
    }

    private func pill(_ title: String, symbol: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(Toy.body(13, weight: .black))
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(Capsule().fill(symbol == nil ? Toy.paper : Toy.card).padding(.vertical, 8))
            .overlay(Capsule().stroke(Toy.ink, lineWidth: 2).padding(.vertical, 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingsLine(_ text: String, link: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ErrorLine(text: text, size: 13)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(link)
                    .font(Toy.body(13, weight: .black))
                    .underline()
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func modeCard(_ mode: Mode, cards: ModeCards) -> some View {
        let color = mode.color(for: draft.persona)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(
                    systemName: mode == .boxing
                        ? (cards.identity?.symbol ?? mode.symbol) : mode.symbol(for: draft.persona)
                )
                .font(.system(size: 18, weight: .bold))
                if mode == .boxing {
                    Text(cards.title(for: mode, persona: draft.persona)).font(Toy.body(17, weight: .black))
                } else {
                    // The default name shows as the prompt, in ink like a typed name.
                    TextField(
                        "", text: name(mode), prompt: Text(mode.title(for: draft.persona)).foregroundStyle(Toy.ink)
                    )
                    .font(Toy.body(17, weight: .black))
                    .foregroundStyle(Toy.ink)
                    .focused($naming, equals: mode)
                    .submitLabel(.done)
                    .fixedSize()
                    Image(systemName: "pencil").font(.system(size: 13, weight: .heavy))
                }
                Spacer(minLength: 4)
                Text(howItSwitches(mode, cards: cards))
                    .font(Toy.body(11, weight: .bold))
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(color)
            VStack(alignment: .leading, spacing: 6) {
                if naming == mode {
                    fine("卡名会显示在锁屏、小组件和手表上。最多 4 个汉字或 8 个字母。")
                }
                let items = activities(mode, cards: cards)
                if items.isEmpty {
                    fine(mode == .work ? "到了、犯困、加班，它看得出来，不用勾。" : "这张卡本身就是活动。")
                } else {
                    FlowRow(items: items)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toyCard(radius: 16, shadow: 4)
    }

    private func note(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).font(.system(size: 15, weight: .bold))
            Text(text).font(Toy.body(13, weight: .bold))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Toy.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Toy.ink, style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])))
        .transition(.opacity)
    }

    private func fine(_ text: String) -> some View {
        Text(text).font(Toy.body(12.5, weight: .bold)).foregroundStyle(Toy.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func primary(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Toy.body(17, weight: .black))
                .frame(maxWidth: .infinity, minHeight: 52)
                .toyCard(fill: enabled ? Toy.pink : Toy.paper, radius: 14, shadow: enabled ? 4 : 0)
                .foregroundStyle(enabled ? Toy.ink : Toy.muted)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Toy.body(17, weight: .black))
                .frame(maxWidth: .infinity, minHeight: 52)
                .toyCard(radius: 14, shadow: 4)
        }
        .buttonStyle(.plain)
    }

    private func textButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Toy.body(15, weight: .heavy))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func next() {
        naming = nil
        history.append(draft.step)
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.32)) {
            draft.advance()
        }
        if draft.step == .done { onDone(draft) }
    }

    private func goBack() {
        guard let previous = history.popLast() else { return }
        naming = nil
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.32)) {
            draft.step = previous
        }
    }

    // 活动分类 v1: one activity sits on one card, so the fitness card takes 健身 out of Chill.
    private func pick(_ kind: IdentityKind) {
        withAnimation(.easeOut(duration: 0.25)) {
            draft.identity = draft.identity == kind ? nil : kind
            movedFitness = draft.identity == .fitness && draft.chill?.contains(.fitness) == true
            if movedFitness { draft.chill?.remove(.fitness) }
        }
    }

    private func toggle(_ state: SideHustle) {
        var picked = draft.sideStates ?? []
        if let index = picked.firstIndex(of: state) {
            picked.remove(at: index)
            sideFull = 0
        } else if picked.count >= ModeCards.sideStateLimit {
            sideFull += 1
            return
        } else {
            picked.append(state)
        }
        draft.sideStates = picked
    }

    private func skipSide() {
        draft.sideStates = nil
        next()
    }

    private func setHere(_ row: PlaceRow) async {
        locating = row.id
        defer { locating = nil }
        do {
            let coordinate = try await monitor.currentLocation().coordinate
            places.save(row.place(coordinate.latitude, coordinate.longitude))
            error = nil
        } catch {
            self.error = "拿不到当前位置：\(error.localizedDescription)"
        }
    }

    // MARK: - Data

    private var chillColor: Color { Mode.chill.color(for: draft.persona) }
    private var workColor: Color { Mode.work.color(for: draft.persona) }

    // Only each character's own identity look is drawn; other cards show her idle until UI draws them.
    private var shownLook: Mode {
        guard let identity = draft.identity, identity == ModeCards.legacy(for: draft.persona).identity else {
            return .chill
        }
        return .boxing
    }

    private var placeRows: [PlaceRow] {
        var rows = [
            PlaceRow(id: HubPlace.Kind.home.rawValue, title: "家", symbol: "house.fill") {
                HubPlace(kind: .home, latitude: $0, longitude: $1)
            },
            PlaceRow(id: HubPlace.Kind.office.rawValue, title: "上班的地方", symbol: "building.2.fill") {
                HubPlace(kind: .office, latitude: $0, longitude: $1)
            },
        ]
        if let identity = draft.identity {
            rows.append(
                PlaceRow(
                    id: identity.placeID, title: "\(identity.placeName) · \(identity.title)卡", symbol: identity.symbol
                ) {
                    identity.place(latitude: $0, longitude: $1)
                }
            )
        }
        rows.append(
            PlaceRow(id: Self.sidePlaceID, title: "副业的地方 · 可选", symbol: "laptopcomputer") {
                .custom(name: "副业的地方", action: .sideHustle, latitude: $0, longitude: $1, id: Self.sidePlaceID)
            }
        )
        return rows
    }

    private func activities(_ mode: Mode, cards: ModeCards) -> [String] {
        switch mode {
        case .chill: ["在家休息"] + ChillActivity.allCases.filter(cards.chill.contains).map(\.title)
        case .money: cards.sideStates.map(\.title)
        case .work, .boxing: []
        }
    }

    private func howItSwitches(_ mode: Mode, cards: ModeCards) -> String {
        switch mode {
        case .work:
            let name = draft.names[Mode.work.rawValue].flatMap { $0.isEmpty ? nil : $0 }
            return name.map { "到「\($0)」的地方 · 手动" } ?? "到上班的地方 · 手动"
        case .chill: return "回家 · 从上班的地方离开 · 手动"
        case .money: return "手动 · 地点可选"
        case .boxing: return cards.identity.map { "\($0.howItSwitches) · 手动" } ?? "手动"
        }
    }

    private func name(_ mode: Mode) -> Binding<String> {
        Binding {
            draft.names[mode.rawValue] ?? ""
        } set: { text in
            draft.names[mode.rawValue] = ModeCards.fitted(text)
        }
    }

    // Written the way the time pickers show it, so 9:00 AM in English and 9:00 in Chinese.
    /// `minute` after midnight as a short clock time in the current locale.
    private func clock(_ minute: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func minuteBinding(_ minute: Binding<Int>) -> Binding<Date> {
        Binding {
            Calendar.current.date(
                bySettingHour: minute.wrappedValue / 60, minute: minute.wrappedValue % 60, second: 0, of: .now)
                ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            minute.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }

    private func line(_ key: OnboardingLine) -> String {
        key.text(for: draft.persona)
    }

    private static let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private static let sideStates: [SideHustle] = [.project, .vibeCoding, .shooting, .writing, .operating, .studying]
    private static let sidePlaceID = "onboardingSide"
}

/// A place the places screen offers to set where the user stands.
private struct PlaceRow {
    let id: String
    let title: String
    let symbol: String
    let place: (Double, Double) -> HubPlace
}

/// Activity names in rows that wrap.
private struct FlowRow: View {
    let items: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(Toy.body(13, weight: .heavy))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Toy.paper))
                    .overlay(Capsule().stroke(Toy.ink, lineWidth: 2))
            }
        }
    }
}

/// Places subviews left to right and starts a new row when one would pass the proposed width.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let frames = self.frames(for: subviews, width: proposal.width ?? .infinity)
        let width = frames.map(\.maxX).max() ?? 0
        let height = frames.map(\.maxY).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = self.frames(for: subviews, width: bounds.width)
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func frames(for subviews: Subviews, width: CGFloat) -> [CGRect] {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return frames
    }
}

// PM 03 Product/onboarding 文案 v0: each character asks in her own words.
/// The character's line on each screen.
private enum OnboardingLine {
    case intro, chill, identity, identityPicked, bedtime, work, irregular, location, places, motion, sideHustle
    case health, cards, notifications

    func text(for persona: Persona) -> String {
        persona == .kuro ? kuro : haku
    }

    private var haku: String {
        switch self {
        case .intro: "……新来的？你平时一天都在干嘛？"
        case .chill: "下班以后呢？"
        case .identity: "有没有一件事，做的时候觉得「这就是我」？没有也行。"
        case .identityPicked: "……这样？"
        case .bedtime: "一般几点睡？"
        case .work: "哪几天上班？"
        case .irregular: "……行，那我不管时间了。"
        case .location: "你到公司、回家，我自己换衣服。要知道你在哪。"
        case .places: "常去哪儿？"
        case .motion: "你走路还是坐车，我想跟着演。"
        case .sideHustle: "下班以后还在弄自己的事吗？"
        case .health: "你睡得少我会困。你练完我会知道。要看看你的睡眠和运动。"
        case .cards: "……就这样吧。"
        case .notifications: "一天最多找你一次。早上不吵你。"
        }
    }

    private var kuro: String {
        switch self {
        case .intro: "……你好。你平时一天都怎么过？"
        case .chill: "下班以后会做什么？"
        case .identity: "有没有一件特别属于你的事？没有也没关系。"
        case .identityPicked: "……这样可以吗？"
        case .bedtime: "一般几点睡呀？"
        case .work: "哪几天要上班？"
        case .irregular: "……好，那就看你去哪儿。"
        case .location: "你到了哪里，我就跟着换样子。可以让我知道你在哪吗？"
        case .places: "常去哪里？"
        case .motion: "你在走路还是坐车，我想跟着一起。"
        case .sideHustle: "有没有下班后自己在做的事？"
        case .health: "你睡得好不好、有没有动一动，我想知道。"
        case .cards: "……就这样。以后慢慢来。"
        case .notifications: "一天最多跟你说一次话，早上不打扰。"
        }
    }
}

extension ChillActivity {
    /// The SF Symbol on the setup's chip.
    fileprivate var symbol: String {
        switch self {
        case .fitness: "dumbbell.fill"
        case .running: "figure.run"
        case .walking: "sun.max.fill"
        case .yoga: "figure.yoga"
        case .cycling: "bicycle"
        case .swimming: "figure.pool.swim"
        case .ball: "basketball.fill"
        case .shopping: "bag.fill"
        }
    }

    /// What tells the app the activity happened.
    fileprivate var source: String {
        switch self {
        case .fitness: "地点 · 手表"
        case .shopping: "地点"
        default: "手表"
        }
    }
}

extension SideHustle {
    /// The SF Symbol on the setup's chip.
    fileprivate var symbol: String {
        switch self {
        case .project: "laptopcomputer"
        case .vibeCoding: "chevron.left.forwardslash.chevron.right"
        case .shooting: "camera.fill"
        case .writing: "pencil"
        case .operating: "scissors"
        case .studying: "graduationcap.fill"
        }
    }
}

extension IdentityKind {
    /// Where the card's place usually is, for the places screen.
    fileprivate var placeName: String {
        switch self {
        case .boxing: "拳馆"
        case .tennis: "球场"
        case .fitness: "健身房"
        case .study: "图书馆"
        case .art: "画室"
        default: "\(title)的地方"
        }
    }

    /// How the card switches, under its name.
    fileprivate var howItSwitches: String {
        workouts.isEmpty ? placeName : "\(placeName) · 手表"
    }

    fileprivate var placeID: String { self == .boxing ? HubPlace.Kind.gym.rawValue : "onboardingIdentity" }

    // The boxing card keeps the preset gym; any other card's place switches to the same slot.
    /// The card's place at the given coordinate.
    fileprivate func place(latitude: Double, longitude: Double) -> HubPlace {
        guard self != .boxing else { return HubPlace(kind: .gym, latitude: latitude, longitude: longitude) }
        return .custom(name: placeName, action: .boxing, latitude: latitude, longitude: longitude, id: placeID)
    }
}

/// The permission requests the setup makes after its own screen says what each is for.
@MainActor
enum OnboardingAccess {
    /// Asks for location, starting with "While Using" and provisional "Always".
    /// - Returns: whether the app may use location now.
    static func location() async -> Bool {
        let status = await LocationAsk().run()
        return status == .authorizedAlways || status == .authorizedWhenInUse
    }

    /// Shows the Motion & Fitness prompt with a one-minute query.
    static func motion() async {
        _ = try? await CommuteMotion.samples(from: .now.addingTimeInterval(-60))
    }

    // One sheet for everything the app reads: sleep, workouts, steps, stand hours and daylight.
    /// Asks for read access to what HealthMotion and HealthSleep read.
    nonisolated static func health() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let read: Set<HKObjectType> = [
            HKCategoryType(.sleepAnalysis), HKObjectType.workoutType(), HKQuantityType(.stepCount),
            HKCategoryType(.appleStandHour), HKQuantityType(.timeInDaylight),
        ]
        try? await HKHealthStore().requestAuthorization(toShare: [], read: read)
    }

    /// Asks to send notifications.
    static func notifications() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }
}

/// Waits for the answer to the location prompt.
@MainActor
private final class LocationAsk: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    func run() async -> CLAuthorizationStatus {
        guard manager.authorizationStatus == .notDetermined else { return manager.authorizationStatus }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.delegate = self
            manager.requestAlwaysAuthorization()
        }
    }

    // The manager was made on the main thread, so it calls back there.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated { finish(status) }
    }

    private func finish(_ status: CLAuthorizationStatus) {
        guard status != .notDetermined, let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: status)
    }
}
