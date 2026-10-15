import Foundation

/// The situation a HAKU line is picked for.
public enum LineScene: String, CaseIterable, Sendable {
    case work
    case chill
    case boxing
    case money
    case couchScroll
    case boxingWarmup
    case gymDay
    case slacking
    case drowsy
    case overtime
    case comeHome
    case lazyEvening
    case morning
    case timeToLeave
    case bedtime
    case lowEnergy
}

// Persona spec: 03 Product/companion/RUNNER 人设.md. Rules pick the line (T0); no model is used.
// Lock-screen lines stay around 14 characters and never name an app.
/// HAKU's short lines for the Lock Screen and widgets.
public enum HakuLines {
    /// Lines per scene, in rotation order.
    public static let library: [LineScene: [String]] = [
        .work: [
            "又上班。",
            "人类为什么发明周一。",
            "我在。灵魂不在。",
            "摸鱼也是一种技术。",
            "今天也是打工人。",
            "在忙。……装的。",
            "耳机戴上，世界关掉。",
            "今天也在假装认真。",
            "摸鱼……不是，在工作。",
        ],
        .chill: [
            "回来了？",
            "饭呢。",
            "今天不想动，你呢。",
            "沙发归我一半。",
            "终于。",
            "今天就到这吧。",
            "我先喝一罐。",
            "瘫着呢。化了。",
            "你看你的。我就在这。",
            "喂。",
        ],
        .boxing: [
            "今天手有点痒。",
            "来几组？",
            "……其实还挺想打的。",
        ],
        // PM 台词泛化 v0: 副业 is the user's own thing, not money.
        .money: [
            "自己的事，开工。",
            "别吵，在弄。",
            "这个我想做完。",
            "再一点点。",
            "下班以后才是正事。",
            "……停不下来。",
            "副业时间。",
            "今天进展一点也算。",
        ],
        .couchScroll: [
            "再刷五分钟。",
            "我也在刷。",
            "手机比我好看？",
            "我们是不是被吸进去了。",
            "运动包在看你。",
            "要不……下楼？",
            "走到门口就算赢。",
            "……我们今天真不动了？",
        ],
        .boxingWarmup: [
            "拳套我都戴好了，你随意啊。",
            "我热身热得都快累了。",
            "拳馆在等你。",
        ],
        .gymDay: [
            "包我背好了。",
            "门就在那。",
            "去不去？我只是问问。",
        ],
        .slacking: [
            "嘘，我帮你望风。",
            "……被抓到我就装不认识你。",
            "我也在摸。",
            "屏幕后面有我。",
            "我什么都没看见。",
            "摸鱼搭子上线。",
            "我帮你盯着门口。",
        ],
        .drowsy: [
            "眼皮好重……",
            "来罐能量饮料？",
            "下午的魔咒。",
            "我先闭眼五秒。",
            "咖啡因在路上了。",
            "哈——欠。",
            "键盘好软，好想趴。",
        ],
        .overtime: [
            "灵魂先下班了。",
            "我先趴一会。",
            "……还不走吗。",
            "感觉就剩我们了。",
            "我的电量也没了。",
            "我的下班时间去哪了。",
            "我在桌上化了。",
        ],
        .comeHome: [
            "你也活着回来了啊。",
            "先让我趴五分钟。",
            "今天的我已经关机。",
            "鞋都懒得脱了。",
            "回来了。我先瘫了。",
            "沙发扶手最懂我。",
            "……回来了就好。",
        ],
        .lazyEvening: [
            "今天就这样吧。",
            "毯子分你一半。",
            "什么都不做也行。",
            "今晚不营业。",
            "躺着也算活着。",
            "我是一团毯子。",
            "明天的事明天说。",
        ],
        .morning: [
            "又要上班了。",
            "耳机……耳机呢。",
            "牙刷了，魂没醒。",
            "外套在哪来着。",
            "早上好。大概吧。",
            "今天也得出门啊。",
            "再给我一分钟。",
        ],
        .timeToLeave: [
            "……我包背好了。",
            "唉。我也不想去。",
            "表在走，我们没走。",
            "我耳机都戴好了。",
            "……要不，出发？",
            "门就在这儿。",
            "我先叹口气。",
        ],
        .bedtime: [
            "我先睡了。你随意。",
            "晚安。我不和天花板开会。",
            "手机也要睡觉。",
            "明天再说。",
            "我眼睛闭上了。",
            "晚安。世界不会跑。",
            "再看我就醒了。",
            "眼皮在打架。",
            "晚安。真的晚安。",
        ],
        .lowEnergy: [
            "……省电中。",
            "我也只睡了一点点。",
            "今天低电量模式。",
            "能躺我就不坐。",
            "慢慢来。",
            "今天算了也行。",
            "我先充个电。",
        ],
    ]

    // One line per scene per hub day, moving to the next each day, so a line only comes back
    // after all the others in its scene have had a day. Daily scenes have 7 or more lines, so none
    // repeats within a week. No history to store, and widgets get the
    // same answer as the app.
    /// The line for `scene` on the hub day containing `date`, in `persona`'s voice.
    /// - Parameter cards: the user's cards, so the identity card's scenes use its own lines.
    public static func line(
        _ scene: LineScene,
        at date: Date,
        calendar: Calendar = .current,
        persona: Persona = .haku,
        cards: ModeCards? = nil
    ) -> String {
        let lines = pool(scene, persona: persona, cards: cards)
        guard !lines.isEmpty else { return "" }
        let day = StateEngine.dayStart(for: date, calendar: calendar)
        let origin = Date(timeIntervalSinceReferenceDate: 0)
        let days = calendar.dateComponents([.day], from: origin, to: day).day ?? 0
        return lines[((days % lines.count) + lines.count) % lines.count].localized(for: persona)
    }

    // 台词 泛化修改 v0 §1, §3: the character's own lines stay for her default card (拳击 for HAKU, 网球 for
    // KURO); another card brings its own, and a user with no sport gets no sports bag.
    /// The lines for `scene` in `persona`'s voice, fitted to `cards`.
    public static func pool(_ scene: LineScene, persona: Persona, cards: ModeCards?) -> [String] {
        let base = (persona == .kuro ? KuroLines.library : library)[scene] ?? []
        guard let cards else { return base }
        let own = cards.identity == ModeCards.legacy(for: persona).identity
        switch scene {
        case .boxing:
            guard let identity = cards.identity, !own else { return base }
            return identity.lines(for: persona)
        case .boxingWarmup:
            guard let identity = cards.identity, !own else { return base }
            let haku = ["……准备好了。你呢。", "我先热个身。", "今天那个，去吗。"]
            let kuro = ["……准备好了。", "手腕转好了。你呢。", "……去吗。"]
            return [identity.invite(for: persona)] + (persona == .kuro ? kuro : haku)
        case .couchScroll:
            let tennisBag = "网球包在门口。"
            let lines = base.map { $0 == tennisBag && !own ? "……一起躺会儿？" : $0 }
            guard !cards.isSporty else { return lines }
            let bags = ["运动包在看你。", "门口那个包，在看你。"]
            if persona == .kuro { return lines.filter { !bags.contains($0) } }
            return lines.map { bags.contains($0) ? "……我也躺会儿。" : $0 }
        default:
            return base
        }
    }

    /// HAKU's one line when leaving the office ends work.
    public static let offWorkLine = "……收工。"

    /// The off-work line in `persona`'s voice.
    /// - Parameters:
    ///   - persona: whose voice says the line.
    ///   - evening: whether the leave came after the evening extension started.
    public static func offWorkLine(for persona: Persona, evening: Bool = false) -> String {
        guard persona == .kuro else { return offWorkLine.localized(for: persona) }
        return (evening ? KuroLines.eveningOffWorkLine : KuroLines.offWorkLine).localized(for: persona)
    }

    /// The off-work line in `persona`'s voice for a line that stops showing at `until`.
    public static func offWorkLine(
        for persona: Persona,
        until: Date,
        work: ModeRules,
        calendar: Calendar = .current
    ) -> String {
        let left = until.addingTimeInterval(-offWorkLasts)
        return offWorkLine(for: persona, evening: work.isEvening(left, calendar: calendar))
    }
    /// How long the off-work line stays after Mike leaves the office.
    public static let offWorkLasts: TimeInterval = 30 * 60

    // PRD section 16, Mike 2026-10-05: no line while packing up, one line the moment he leaves.
    // Leaving the office is the only automatic change from work to chill in the evening that isn't a pass-by.
    /// When the off-work line stops showing, if leaving the office ended work within `offWorkLasts` of `now`.
    /// - Parameter work: the work hours, for when leaving ends work.
    /// - Returns: `nil` when the latest change isn't that leave or the line has run its time.
    public static func offWorkUntil(
        _ log: ModeLog,
        now: Date,
        work: ModeRules = .standard,
        calendar: Calendar = .current
    ) -> Date? {
        let changes = log.active.filter { $0.at <= now }
        guard let left = changes.last, let before = changes.dropLast().last else { return nil }
        guard left.mode == .chill, left.source == .location, before.mode == .work else { return nil }
        guard left.at.timeIntervalSince(before.at) >= PlacePresence.bounce else { return nil }
        let parts = calendar.dateComponents([.hour, .minute], from: left.at)
        guard (parts.hour ?? 0) * 60 + (parts.minute ?? 0) >= work.offWorkFromMinute else { return nil }
        let until = left.at.addingTimeInterval(offWorkLasts)
        return now < until ? until : nil
    }

    /// The scene for a state that has its own lines, `nil` for the others.
    public static func scene(for moment: CompanionMoment) -> LineScene? {
        switch moment {
        case .slacking: .slacking
        case .drowsy: .drowsy
        case .overtime: .overtime
        case .collapsed: .comeHome
        case .blanket: .lazyEvening
        case .morning: .morning
        case .timeToLeave: .timeToLeave
        default: nil
        }
    }

    /// The scene for HAKU's state: bedtime, then the need, then low energy, then the mode.
    /// - Returns: `nil` before any mode is set and with nothing else to say.
    public static func scene(
        mode: Mode?,
        need: CompanionNeed?,
        energy: EnergyLevel?,
        bedtime: Bedtime
    ) -> LineScene? {
        if bedtime == .on { return .bedtime }
        switch need {
        case .couchScroll: return .couchScroll
        case .boxingWarmup: return .boxingWarmup
        case .gymDay: return .gymDay
        case .slacking: return .slacking
        case .sitting, nil: break
        }
        if energy == .low { return .lowEnergy }
        switch mode {
        case .work: return .work
        case .chill: return .chill
        case .boxing: return .boxing
        case .money: return .money
        case nil: return nil
        }
    }
}
