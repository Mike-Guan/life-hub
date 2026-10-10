import CompanionKit
import HubCore
import SwiftUI

// Issue #237 (PRD §21.2, Mike 2026-10-10): the companion's memory without a list of days, so she keeps
// some mystery. Habits are forgotten one by one; her judgements and everything she remembers can be
// deleted. Cans, items and keepsakes are not memories and stay.
/// What the companion remembers: learned habits, long-term memories and her judgements.
struct MemoryView: View {
    let persona: Persona
    let store: ModeStore
    let energy: EnergyStore
    let ledger: CanLedger
    let places: [HubPlace]
    let decisionLogURL: URL?
    @Environment(\.dismiss) private var dismiss
    @State private var resets = MemoryResets.stored(in: AppGroup.defaults)
    @State private var decisions = DecisionLog()
    @State private var asking: Forget?
    @State private var error: String?

    /// What a delete button asks to forget.
    enum Forget: Identifiable {
        case habit(LearnedHabit)
        case decisions
        case everything

        var id: String {
            switch self {
            case .habit(let habit): habit.habit.rawValue
            case .decisions: "decisions"
            case .everything: "everything"
            }
        }
    }

    var body: some View {
        ScrollView {
            content
        }
        .foregroundStyle(Toy.ink)
        .tint(Toy.pink)
        .background(Toy.paper.ignoresSafeArea())
        .preferredColorScheme(.light)
        .confirmationDialog(
            asking.map { question($0) } ?? "",
            isPresented: Binding(get: { asking != nil }, set: { if !$0 { asking = nil } }),
            titleVisibility: .visible,
            presenting: asking
        ) { item in
            Button(confirm(item), role: .destructive) { forget(item) }
            Button("算了", role: .cancel) {}
        } message: { item in
            Text(warning(item))
        }
        .task { decisions = DecisionLog.read(from: decisionLogURL) }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("\(persona.title) 记得的")
                    .font(Toy.display(24))
                Spacer()
                Button("好了") { dismiss() }
                    .font(Toy.body(15, weight: .heavy))
                    .frame(minWidth: 44, minHeight: 44)
            }

            section("学到的习惯") {
                ForEach(habits, id: \.habit) { habit in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(habit.title)：\(habit.days)")
                                .font(Toy.body(15, weight: .heavy))
                            Text(habit.isLearned ? "从你去的日子学的" : "默认的，还在学")
                                .font(Toy.body(12))
                                .foregroundStyle(Toy.muted)
                        }
                        Spacer()
                        if habit.isLearned {
                            deleteButton("忘掉") { asking = .habit(habit) }
                        }
                    }
                }
                note("忘掉后回到默认，再从你之后的日子重新学。")
            }

            section("长期记得的事") {
                if longTerm.isEmpty {
                    note("还没有。")
                }
                ForEach(longTerm, id: \.title) { memory in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(memory.title)
                            .font(Toy.body(15, weight: .heavy))
                        Text(memory.date.map(Self.day) ?? memory.detail ?? "")
                            .font(Toy.body(12))
                            .foregroundStyle(Toy.muted)
                    }
                }
                note("从你的记录里自己记下的，只能看。")
            }

            section("\(persona.title) 的判断") {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(judgements)
                            .font(Toy.body(15, weight: .heavy))
                        Text("要不要提醒你，和你说「不对」的那几次。保留 90 天。")
                            .font(Toy.body(12))
                            .foregroundStyle(Toy.muted)
                    }
                    Spacer()
                    if !decisions.kept.isEmpty {
                        deleteButton("全部删") { asking = .decisions }
                    }
                }
            }

            if let error {
                ErrorLine(text: error)
            }

            Button {
                asking = .everything
            } label: {
                Text("删掉所有记忆")
                    .font(Toy.body(15, weight: .heavy))
                    .foregroundStyle(Toy.alert)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(ToyButtonStyle(fill: Toy.card))
            note("能量罐、商店物品、衣柜和纪念品不算记忆，留着。")
        }
        .padding(20)
    }

    private var habits: [LearnedHabit] {
        Memory.habits(
            persona: persona,
            days: ActivityDays.stored(in: AppGroup.defaults),
            ledger: ledger,
            resets: resets,
            now: .now
        )
    }

    private var longTerm: [LongMemory] {
        Memory.longTerm(persona: persona, changes: store.log.changes, ledger: ledger, places: places, resets: resets)
    }

    private var judgements: String {
        let kept = decisions.kept
        guard !kept.isEmpty else { return "还没有判断" }
        let corrected = kept.filter { $0.feedback == .corrected }.count
        return corrected == 0 ? "\(kept.count) 次判断" : "\(kept.count) 次判断 · 纠正 \(corrected) 次"
    }

    private func section<Rows: View>(_ title: String, @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Toy.body(16, weight: .heavy))
            rows()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .toyCard()
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Toy.body(12))
            .foregroundStyle(Toy.muted)
    }

    private func deleteButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(Toy.body(13, weight: .heavy))
            .foregroundStyle(Toy.alert)
            .frame(minHeight: 44)
    }

    private func question(_ item: Forget) -> String {
        switch item {
        case .habit(let habit): "忘掉\(habit.title)？"
        case .decisions: "删掉 \(persona.title) 的所有判断？"
        case .everything: "删掉所有记忆？"
        }
    }

    private func warning(_ item: Forget) -> String {
        switch item {
        case .habit: "回到默认，再慢慢重新学。"
        case .decisions: "包括你说过「不对」的记录。删了不能恢复。"
        case .everything:
            "习惯、长期记得的事、每天的记录和判断都会删掉，\(persona.title) 像第一次认识你。"
                + "能量罐和物品留着。删了不能恢复。"
        }
    }

    private func confirm(_ item: Forget) -> String {
        switch item {
        case .habit: "忘掉"
        case .decisions, .everything: "全部删"
        }
    }

    private func forget(_ item: Forget) {
        let now = Date.now
        switch item {
        case .habit(let habit):
            resets.habits[habit.habit] = now
            resets.store(in: AppGroup.defaults)
        case .decisions:
            error = forgetDecisions(at: now)
        case .everything:
            store.forget(at: now) { _ in true }
            energy.forget(at: now) { _ in true }
            var moments = ChangeLog.stored(in: AppGroup.defaults)
            moments.forgetAll(at: now, by: store.deviceID)
            moments.store(in: AppGroup.defaults)
            resets.all = now
            resets.store(in: AppGroup.defaults)
            error = forgetDecisions(at: now) ?? store.lastError ?? energy.lastError
        }
    }

    /// Deletes every judgement.
    /// - Returns: an error message, or `nil` on success.
    private func forgetDecisions(at date: Date) -> String? {
        let deviceID = store.deviceID
        let error = DecisionLog.update(at: decisionLogURL, now: date) { log in
            log.forget(at: date, by: deviceID, where: { _ in true }) > 0
        }
        DecisionLog.keep(error, in: AppGroup.defaults)
        decisions = DecisionLog.read(from: decisionLogURL)
        return error
    }

    /// `date` as e.g. "10月4日 周日".
    static func day(_ date: Date) -> String {
        // FormatStyle drew "9/12周六"; a fixed pattern keeps the 月/日 words and the space.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEE"
        return formatter.string(from: date)
    }
}
