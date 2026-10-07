import Foundation

// Issue #177, approved by Mike on 2026-10-07: opening the app after days away shows what real life
// recorded meanwhile. It never names the days away, never compares, and the return itself gives no cans.
/// What HAKU shows when Mike opens the app after several days away.
public struct ReturnReplay: Equatable, Sendable {
    /// How big the return is.
    public enum Tier: Int, Sendable {
        /// 3 to 7 days away: HAKU looks up, then up to 3 cards.
        case glance = 1
        /// 8 days or more: the return animation, up to 5 cards and the cans opened together.
        case box = 2
    }

    public var tier: Tier
    /// What was recorded while away, most notable first.
    public var cards: [ReturnCard]
    /// Cans earned while away. Only `.box` opens them; the return itself adds none.
    public var cans: Int

    /// Whether nothing was recorded while away, so HAKU only makes room on the sofa.
    public var isQuiet: Bool { cards.isEmpty && cans == 0 }

    /// HAKU's line as the replay starts.
    public var line: String {
        if isQuiet { return "……坐。" }
        return tier == .box ? "……又不是在等你。" : "哦，回来了。"
    }

    public init(tier: Tier, cards: [ReturnCard], cans: Int) {
        self.tier = tier
        self.cards = cards
        self.cans = cans
    }

    /// Fewer hub days away than this keep the usual open replay.
    public static let glanceFromDays = 3
    /// From this many hub days away the return is `.box`.
    public static let boxFromDays = 8
    /// How long after one `.box` return the next one falls back to `.glance`.
    public static let boxEvery: TimeInterval = 30 * 24 * 60 * 60

    /// The replay for opening the app at `now`, or `nil` when Mike was away too briefly.
    /// - Parameters:
    ///   - lastSeen: when the app last went to the background, `nil` if never.
    ///   - lastBox: when the last `.box` return played, `nil` if never.
    ///   - ledger: the can ledger, read after this open's wins are recorded.
    ///   - nights: the nights slept while away, read back from Health.
    ///   - log: the mode log, for room traces that appeared while away.
    ///   - now: the time the app opens.
    ///   - calendar: the calendar for hub days.
    public static func make(
        lastSeen: Date?,
        lastBox: Date?,
        ledger: CanLedger,
        nights: [SleepNight],
        log: ModeLog,
        now: Date,
        calendar: Calendar = .current
    ) -> ReturnReplay? {
        guard let lastSeen, lastSeen < now else { return nil }
        let from = StateEngine.dayStart(for: lastSeen, calendar: calendar)
        let to = StateEngine.dayStart(for: now, calendar: calendar)
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        guard days >= glanceFromDays else { return nil }
        let boxAllowed = lastBox.map { now.timeIntervalSince($0) >= boxEvery } ?? true
        let tier: Tier = days >= boxFromDays && boxAllowed ? .box : .glance
        let away = ledger.active.filter { $0.at > lastSeen && $0.at <= now }
        let earned = away.filter { $0.kind == .earned }
        let cards = ReturnCard.cards(
            earned: earned,
            granted: away.filter { $0.kind == .granted },
            nights: nights.filter { $0.endedAt > lastSeen && $0.endedAt <= now },
            traces: newTraces(log: log, ledger: ledger, since: lastSeen, now: now)
        )
        let limit = tier == .box ? 5 : 3
        return ReturnReplay(tier: tier, cards: Array(cards.prefix(limit)), cans: earned.reduce(0) { $0 + $1.cans })
    }

    /// The lasting room traces present at `now` that weren't at `since`.
    static func newTraces(log: ModeLog, ledger: CanLedger, since: Date, now: Date) -> [CompanionTrace] {
        let before = CanLedger(entries: ledger.active.filter { $0.at <= since })
        let old = MomentEngine.lastingTraces(log: log, ledger: before, now: since)
        let new = MomentEngine.lastingTraces(log: log, ledger: ledger, now: now)
        return CompanionTrace.allCases.filter { new.contains($0) && !old.contains($0) }
    }
}

/// One thing recorded while Mike was away, said plainly.
public struct ReturnCard: Equatable, Sendable {
    /// What the card is about.
    public enum Kind: String, Sendable {
        case boxing
        case run5k
        case gym
        case sleptWell
        case plannedTask
        case trace
        case keepsake
    }

    public var kind: Kind
    /// How many times it happened; 1 for a trace or a keepsake.
    public var count: Int
    /// The trace's raw value or the keepsake's item id, else `nil`.
    public var item: String?
    /// The card's line.
    public var text: String

    public init(kind: Kind, count: Int, item: String? = nil, text: String) {
        self.kind = kind
        self.count = count
        self.item = item
        self.text = text
    }

    /// The cards for what was recorded, in a fixed order: workouts, sleep, planned tasks, traces, keepsakes.
    static func cards(
        earned: [CanEntry],
        granted: [CanEntry],
        nights: [SleepNight],
        traces: [CompanionTrace]
    ) -> [ReturnCard] {
        func count(_ win: Win) -> Int { earned.filter { $0.win == win }.count }
        let fullFrom = SleepThresholds.standard.fullFrom
        let slept = Set(nights.filter { $0.minutes >= fullFrom }.map(\.id)).count
        var cards: [ReturnCard] = []
        func add(_ kind: Kind, _ count: Int, _ text: String) {
            if count > 0 { cards.append(ReturnCard(kind: kind, count: count, text: text)) }
        }
        add(.boxing, count(.boxing), "打了 \(count(.boxing)) 次拳。")
        add(.run5k, count(.run5k), "跑了 \(count(.run5k)) 次 5 公里。")
        add(.gym, count(.gym), "去了 \(count(.gym)) 次健身房。")
        add(.sleptWell, slept, slept == 1 ? "有一天睡得挺好。" : "有几天睡得挺好。")
        add(.plannedTask, count(.plannedTask), "做完了 \(count(.plannedTask)) 件提前定好的事。")
        for trace in traces {
            guard let line = line(for: trace) else { continue }
            cards.append(ReturnCard(kind: .trace, count: 1, item: trace.rawValue, text: line))
        }
        for entry in granted {
            // The return is HAKU's, so KURO's keepsakes granted at the same milestones stay out.
            guard let id = entry.itemID, let item = ShopItem.item(id), item.persona == .haku else { continue }
            cards.append(ReturnCard(kind: .keepsake, count: 1, item: id, text: "拿到了\(item.title)。"))
        }
        return cards
    }

    static func line(for trace: CompanionTrace) -> String? {
        switch trace {
        case .wornGloves: "拳套磨旧了。"
        case .runningShoes: "门口多了双跑鞋。"
        case .deskMonitor: "桌上多了台显示器。"
        case .bandage, .pcGlow, .sunlight: nil
        }
    }
}

/// When the last `.box` return played, so it plays at most once in `ReturnReplay.boxEvery`, and which
/// time away was already looked at, so one stay in the background is one return.
public enum ReturnLog {
    static let defaultsKey = "returnBoxAt"
    static let pendingKey = "returnPendingSince"
    static let handledKey = "returnHandledAway"

    // Control Center, a permission sheet or Face ID make the app active again without a stay in the
    // background. Without this, the same return would start again and never finish (Issue #184).
    /// The start of the return to look at on this open, `nil` when this open isn't a return.
    /// A pending return comes first. Marks `away` as looked at, so the next call with it returns `nil`.
    /// - Parameters:
    ///   - away: when the app last went to the background, `nil` if never.
    ///   - defaults: where the pending and looked-at times are stored.
    public static func since(away: Date?, in defaults: UserDefaults) -> Date? {
        let pending = defaults.object(forKey: pendingKey) as? Date
        let handled = defaults.object(forKey: handledKey) as? Date
        if let away { defaults.set(away, forKey: handledKey) }
        return pending ?? (away == handled ? nil : away)
    }

    /// Keeps the return starting at `since` for a later open, or drops the kept one when `nil`.
    public static func setPending(_ since: Date?, in defaults: UserDefaults) {
        if let since {
            defaults.set(since, forKey: pendingKey)
        } else {
            defaults.removeObject(forKey: pendingKey)
        }
    }

    /// When the last `.box` return played, `nil` if never.
    public static func lastBox(in defaults: UserDefaults) -> Date? {
        defaults.object(forKey: defaultsKey) as? Date
    }

    /// Records that a `.box` return played at `date`.
    public static func markBox(at date: Date, in defaults: UserDefaults) {
        defaults.set(date, forKey: defaultsKey)
    }
}
