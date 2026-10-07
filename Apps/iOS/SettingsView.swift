import CompanionKit
import FamilyControls
import HubCore
import SwiftUI
import UniformTypeIdentifiers

/// App settings: the bedtime reminder time, the places that switch mode, money, the Daily Widget link and
/// the Screen Time watch.
struct SettingsView: View {
    @Binding var bedtime: BedtimeSchedule
    @Binding var rules: ModeRules
    @Binding var places: PlaceSettings
    @Binding var budget: BudgetSettings
    @Binding var persona: Persona
    let monitor: PlaceMonitor
    let daily: DailyLink
    @Environment(\.dismiss) private var dismiss
    @State private var pickingDaily = false
    @State private var editing: PlaceEdit?
    @State private var scrollApps = ScrollWatch.selection
    @State private var pickingApps = false
    @State private var screenTimeError: String?
    @FocusState private var editingAmount: String?

    var body: some View {
        ScrollView {
            content
        }
        .foregroundStyle(Toy.ink)
        .background(Toy.paper.ignoresSafeArea())
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("设置")
                    .font(Toy.display(24))
                Spacer()
                Button("好了") { dismiss() }
                    .font(Toy.body(15, weight: .heavy))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("角色")
                    .font(Toy.body(16, weight: .heavy))
                Picker("角色", selection: $persona) {
                    ForEach(Persona.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("换的是首页、小组件和手表上的角色。记录和规则都不变。")
                    .font(Toy.body(12))
                    .foregroundStyle(Toy.muted)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("睡觉提醒")
                    .font(Toy.body(16, weight: .heavy))
                DatePicker("睡觉", selection: time($bedtime.startMinute), displayedComponents: .hourAndMinute)
                    .font(Toy.body(15))
                DatePicker("起床", selection: time($bedtime.endMinute), displayedComponents: .hourAndMinute)
                    .font(Toy.body(15))
                Text("睡觉时间到了发一条通知，HAKU 变困，一直到起床时间。只提醒一次。")
                    .font(Toy.body(12))
                    .foregroundStyle(Toy.muted)
            }
            .padding(16)
            .toyCard()

            VStack(alignment: .leading, spacing: 8) {
                Text("上班时段")
                    .font(Toy.body(16, weight: .heavy))
                DatePicker("上班", selection: time($rules.workStartMinute), displayedComponents: .hourAndMinute)
                    .font(Toy.body(15))
                DatePicker("下班", selection: time($rules.workEndMinute), displayedComponents: .hourAndMinute)
                    .font(Toy.body(15))
                Text("到公司才切到上班。在上班的日子，下班前 \(ModeRules.offWorkLead) 分钟提醒一次。")
                    .font(Toy.body(12))
                    .foregroundStyle(Toy.muted)
            }
            .padding(16)
            .toyCard()

            placesCard

            moneyCard

            dailyCard

            // Debug only until Apple approves Family Controls for distribution; STG and PROD have no
            // entitlement, so the button could only fail. Remove with the CI-CD.md Screen Time step.
            #if DEBUG
            scrollCard
            dogfoodCard
            #endif
        }
        .padding(20)
    }

    private var moneyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("钱")
                .font(Toy.body(16, weight: .heavy))
            yenField("银行余额", text: yenText(budget.balance) { budget.enterBalance($0, at: .now) })
            yenField("金库目标", text: yenText(budget.savingsTarget) { budget.savingsTarget = $0 })
            Text("发薪日填一次银行余额，首页显示离金库目标还差多少。金额只存在这台 iPhone 上。")
                .font(Toy.body(12))
                .foregroundStyle(Toy.muted)
        }
        .padding(16)
        .toyCard()
    }

    private var dailyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: dailyBinding) {
                Text("联动 Daily Widget")
                    .font(Toy.body(16, weight: .heavy))
            }
            Text("打开后选一次 iCloud Drive 里的 Daily Widget 文件夹。只读不写；提前定好的事做完 +1 能量罐，一天最多 3 个。关掉就不再读，已拿的罐子保留。")
                .font(Toy.body(12))
                .foregroundStyle(Toy.muted)
            if let error = daily.lastError {
                Text(error)
                    .font(Toy.body(12))
                    .foregroundStyle(Toy.alert)
            }
        }
        .padding(16)
        .toyCard()
        .fileImporter(isPresented: $pickingDaily, allowedContentTypes: [.folder]) { result in
            guard case .success(let folder) = result else { return }
            Task { await daily.link(folder) }
        }
    }

    // Turning it on opens the folder picker; it shows as on only once a folder is linked.
    private var dailyBinding: Binding<Bool> {
        Binding {
            daily.isOn
        } set: { on in
            if on { pickingDaily = true } else { daily.unlink() }
        }
    }

    private func yenField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Toy.body(13, weight: .bold))
                .foregroundStyle(Toy.muted)
            HStack(spacing: 6) {
                Text("¥")
                    .font(Toy.body(22, weight: .heavy))
                TextField("点这里输入", text: text)
                    .keyboardType(.numberPad)
                    .font(Toy.body(22, weight: .heavy))
                    .focused($editingAmount, equals: title)
                if editingAmount == title {
                    Button("完成") { editingAmount = nil }
                        .font(Toy.body(14, weight: .heavy))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture { editingAmount = title }
            .toyCard(fill: Toy.paper, radius: 12, shadow: 3)
        }
    }

    // Digits only; an empty field clears the amount.
    private func yenText(_ amount: Int?, set: @escaping (Int?) -> Void) -> Binding<String> {
        Binding {
            amount?.formatted(.number.grouping(.automatic)) ?? ""
        } set: { text in
            set(Int(text.filter(\.isNumber)))
        }
    }

    private var scrollCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("刷手机")
                    .font(Toy.body(16, weight: .heavy))
                Text(pickedLabel)
                    .font(Toy.body(12))
                    .foregroundStyle(Toy.muted)
                Spacer()
                Button("选 App") {
                    Task { await pickApps() }
                }
                .font(Toy.body(13, weight: .heavy))
            }
            Text("选 B 站和小红书。一天合计刷满 \(ScrollWatch.minutes) 分钟，HAKU 也瘫在沙发上；停下 20 分钟、走动或手动切模式，它就起来。")
                .font(Toy.body(12))
                .foregroundStyle(Toy.muted)
            if let screenTimeError {
                Text(screenTimeError)
                    .font(Toy.body(12))
                    .foregroundStyle(Toy.alert)
            }
        }
        .padding(16)
        .toyCard()
        .familyActivityPicker(isPresented: $pickingApps, selection: $scrollApps)
        .onChange(of: scrollApps) { watchScrolling() }
    }

    // Debug builds only: the automatic decisions noted during the weeks of use (PRD section 19).
    private var dogfoodCard: some View {
        let log = DogfoodLog.stored(in: AppGroup.defaults)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("调试记录")
                    .font(Toy.body(16, weight: .heavy))
                Text("\(log.entries.count) 条")
                    .font(Toy.body(12))
                    .foregroundStyle(Toy.muted)
                Spacer()
                ShareLink("导出", item: log.text())
                    .font(Toy.body(13, weight: .heavy))
                    .disabled(log.entries.isEmpty)
            }
            ForEach(Array(log.entries.suffix(5).reversed().enumerated()), id: \.offset) { _, entry in
                Text("\(entry.at.formatted(date: .omitted, time: .shortened)) \(entry.kind)：\(entry.detail)")
                    .font(Toy.body(12))
                    .foregroundStyle(Toy.muted)
            }
        }
        .padding(16)
        .toyCard()
    }

    private var pickedLabel: String {
        let apps = scrollApps.applicationTokens.count + scrollApps.categoryTokens.count
        let count = apps + scrollApps.webDomainTokens.count
        return count == 0 ? "没选" : "已选 \(count) 项"
    }

    // Screen Time asks once; after that the picker opens straight away.
    private func pickApps() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            screenTimeError = nil
            pickingApps = true
        } catch {
            screenTimeError = "Screen Time 没打开：\(error.localizedDescription)"
            Dogfood.note("screenTime", "授权失败：\(error.localizedDescription)")
        }
    }

    private func watchScrolling() {
        ScrollWatch.selection = scrollApps
        do {
            try ScrollWatch.start(scrollApps, work: rules)
            screenTimeError = nil
        } catch {
            screenTimeError = "Screen Time 监测没启动：\(error.localizedDescription)"
            Dogfood.note("screenTime", "监测没启动：\(error.localizedDescription)")
        }
    }

    private var placesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("地点")
                    .font(Toy.body(16, weight: .heavy))
                Spacer()
                Button {
                    editing = PlaceEdit(place: .custom(name: "", action: .recordOnly, latitude: 0, longitude: 0))
                } label: {
                    Image(systemName: "plus")
                        .font(Toy.body(16, weight: .heavy))
                        .frame(width: 44, height: 44)
                }
                .disabled(!places.canAdd)
                .accessibilityLabel("添加地点")
            }
            ForEach(HubPlace.Kind.presets, id: \.self) { kind in
                let place = places[kind]
                placeRow(title: kind.title(for: persona), detail: place == nil ? "没设" : "已设") {
                    let blank = HubPlace(kind: kind, latitude: 0, longitude: 0)
                    editing = PlaceEdit(place: place ?? blank, isNew: place == nil)
                }
            }
            ForEach(places.custom) { place in
                placeRow(title: place.title, detail: place.action.title(for: persona)) {
                    editing = PlaceEdit(place: place, isNew: false)
                }
            }
            Text(placesNote)
                .font(Toy.body(12))
                .foregroundStyle(Toy.muted)
        }
        .padding(16)
        .toyCard()
        .sheet(item: $editing) { edit in
            PlaceEditor(
                place: edit.place,
                hasLocation: !edit.isNew,
                monitor: monitor,
                onSave: { places.save($0) },
                onDelete: edit.isNew ? nil : { places.remove(id: edit.place.id) }
            )
        }
    }

    private var placesNote: String {
        let full = places.canAdd ? "" : "iOS 最多同时看 \(PlaceSettings.limit) 个地点，删掉一个才能再加。"
        return full + "点一个地点设置位置。右上角 + 加自己的地点，选到了 HAKU 做什么。"
            + "地点只存在这台 iPhone 上。定位权限选「始终」，App 关着时也能切。"
    }

    private func placeRow(title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(Toy.body(15, weight: .bold))
                Text(detail)
                    .font(Toy.body(12))
                    .foregroundStyle(Toy.muted)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(Toy.body(13, weight: .heavy))
                    .foregroundStyle(Toy.muted)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // The picker edits a Date; only its hour and minute are kept.
    private func time(_ minute: Binding<Int>) -> Binding<Date> {
        Binding {
            let value = minute.wrappedValue
            return Calendar.current.date(from: DateComponents(hour: value / 60, minute: value % 60)) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            minute.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }
}

/// A place open in the editor; `isNew` until it has a location.
private struct PlaceEdit: Identifiable {
    var place: HubPlace
    var isNew = true

    var id: String { place.id }
}
