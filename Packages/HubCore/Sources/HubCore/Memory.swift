import Foundation

// Issue #237 (PRD §21.2, Mike 2026-10-10): the memory page shows what the companion learned and the
// long-term things she remembers, never a list of days. Forgetting a habit or everything sets a date;
// what she learns or remembers only reads records after it, so nothing earned (cans, items) is touched.
/// A habit the companion learns from what the user does.
public enum Habit: String, Codable, CaseIterable, Sendable {
    /// Gym weekdays, from gym wins.
    case gymDays
    /// The identity card's weekday, from its wins. Only KURO's is learned; HAKU's boxing is Sunday.
    case identityDay
}

/// When the user last told the companion to forget, per habit and for everything.
public struct MemoryResets: Codable, Equatable, Sendable {
    /// When everything was forgotten.
    public var all: Date?
    /// When each habit was forgotten.
    public var habits: [Habit: Date]

    public init(all: Date? = nil, habits: [Habit: Date] = [:]) {
        self.all = all
        self.habits = habits
    }

    /// The date records must be after to count for `habit`, or `nil` when it was never forgotten.
    public func since(_ habit: Habit) -> Date? {
        [all, habits[habit]].compactMap(\.self).max()
    }

    static let defaultsKey = "memoryResets"

    /// The resets saved in `defaults`, or none when nothing is saved or it can't be read.
    public static func stored(in defaults: UserDefaults) -> MemoryResets {
        guard let data = defaults.data(forKey: defaultsKey) else { return MemoryResets() }
        return (try? JSONDecoder().decode(MemoryResets.self, from: data)) ?? MemoryResets()
    }

    /// Saves the resets in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }
}

extension CanLedger {
    /// This ledger without the entries before `date`, for learning; the whole ledger when `date` is `nil`.
    public func since(_ date: Date?) -> CanLedger {
        guard let date else { return self }
        var ledger = self
        ledger.entries.removeAll { $0.at < date }
        return ledger
    }
}

/// One habit as the memory page shows it.
public struct LearnedHabit: Equatable, Sendable {
    public var habit: Habit
    public var title: String
    /// The weekdays, e.g. "周二、周四".
    public var days: String
    /// `false` while the default is used because nothing was learned yet.
    public var isLearned: Bool
}

/// One long-term thing the companion remembers.
public struct LongMemory: Equatable, Sendable {
    public var title: String
    /// When it happened, `nil` for a memory that isn't one day.
    public var date: Date?
    /// Words in place of a date, e.g. the places.
    public var detail: String?
}

/// What the memory page lists.
public enum Memory {
    /// The habits `persona` learns, learned from `ledger` after the resets.
    public static func habits(
        persona: Persona,
        days: ActivityDays,
        ledger: CanLedger,
        resets: MemoryResets,
        now: Date,
        calendar: Calendar = .current
    ) -> [LearnedHabit] {
        // Learning from no days at all shows whether any weekday qualified.
        var none = days
        none.gymWeekdays = []
        let learned = none.learningGym(from: ledger.since(resets.since(.gymDays)), now: now, calendar: calendar)
        var list = [
            LearnedHabit(
                habit: .gymDays,
                title: "健身日",
                days: weekdays(learned.gymWeekdays.isEmpty ? days.gymWeekdays : learned.gymWeekdays),
                isLearned: !learned.gymWeekdays.isEmpty
            )
        ]
        if persona == .kuro {
            let identity = ledger.since(resets.since(.identityDay))
            let learned = NeedRules.learnedWeekday(of: .boxing, in: identity, now: now, calendar: calendar)
            list.append(
                LearnedHabit(
                    habit: .identityDay,
                    title: Mode.boxing.title(for: persona),
                    days: weekdays([learned ?? NeedRules.tennisWeekday]),
                    isLearned: learned != nil
                )
            )
        }
        return list
    }

    /// Wins that are a sport done for the first time, with what the memory is called.
    static let firstWins: [(win: Win, title: String)] = [(.gym, "第一次去健身房"), (.run5k, "第一次跑完 5 公里")]
    /// How many automatic switches into a place's mode make it a place the user spends time at.
    static let placeMinimum = 3

    /// The first identity-card day, the first of each sport and the places the user spends most time at,
    /// counting only records after everything was last forgotten.
    public static func longTerm(
        persona: Persona,
        changes: [ModeChange],
        ledger: CanLedger,
        places: [HubPlace],
        resets: MemoryResets
    ) -> [LongMemory] {
        let since = resets.all ?? .distantPast
        let kept = changes.filter { $0.deletedAt == nil && $0.at >= since }.sorted { $0.at < $1.at }
        var list: [LongMemory] = []
        if let first = kept.first(where: { $0.mode == .boxing }) {
            list.append(LongMemory(title: "第一次\(Mode.boxing.title(for: persona))", date: first.at))
        }
        let earned = ledger.since(resets.all).active.filter { $0.kind == .earned }
        for (win, title) in firstWins {
            if let first = earned.first(where: { $0.win == win }) {
                list.append(LongMemory(title: title, date: first.at))
            }
        }
        // Visits aren't stored, so a place counts by the automatic switches into the mode it sets.
        let arrivals = Dictionary(grouping: kept.filter { $0.source == .location }, by: \.mode).mapValues(\.count)
        let often = places.compactMap { place -> (String, Int)? in
            guard let mode = mode(for: place.action), let count = arrivals[mode], count >= placeMinimum else {
                return nil
            }
            return (place.title, count)
        }
        .sorted { $0.1 > $1.1 }
        .prefix(3)
        if !often.isEmpty {
            list.append(LongMemory(title: "常待的地方", detail: often.map(\.0).joined(separator: "、")))
        }
        return list
    }

    /// The mode arriving at a place with `action` switches to, `nil` when arriving switches nothing for sure.
    static func mode(for action: HubPlace.Action) -> Mode? {
        switch action {
        case .work: .work
        case .chill: .chill
        case .boxing: .boxing
        case .sideHustle: .money
        // A fitness gym switches to chill only from work or 副业, so chill there isn't its own.
        case .fitness, .recordOnly: nil
        }
    }

    /// `days` as Chinese weekday names in week order from Monday, e.g. "周二、周四".
    static func weekdays(_ days: Set<Int>) -> String {
        let names = [1: "周日", 2: "周一", 3: "周二", 4: "周三", 5: "周四", 6: "周五", 7: "周六"]
        return days.sorted { ($0 + 5) % 7 < ($1 + 5) % 7 }.compactMap { names[$0] }.joined(separator: "、")
    }
}

extension ChangeLog {
    /// Marks every moment as deleted at `date` by `deviceID`.
    /// - Returns: how many moments were deleted now.
    @discardableResult
    public mutating func forgetAll(at date: Date, by deviceID: String) -> Int {
        var count = 0
        for index in moments.indices where moments[index].deletedAt == nil {
            moments[index].deletedAt = date
            moments[index].updatedAt = date
            moments[index].updatedBy = deviceID
            count += 1
        }
        return count
    }
}
