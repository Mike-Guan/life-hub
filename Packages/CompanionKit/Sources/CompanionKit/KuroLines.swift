import HubCore

// Issue #164. Tier 0: no model. Voice: KURO, quiet and dry, a few words at a time.
// Boxing is her tennis day and the side-hustle slot is her desk time, like `KuroLook`.
/// KURO's fixed lines per mode, need and idle bit.
enum KuroLines {
    /// KURO's lines for the same inputs as `CompanionLines.lines`.
    static func lines(
        for mode: Mode?,
        need: CompanionNeed? = nil,
        peeking: Bool = false,
        life: IdleLife? = nil,
        activity: CompanionActivity? = nil,
        moment: CompanionMoment? = nil
    ) -> [String] {
        if let activity { return lines(for: activity) }
        if let moment { return lines(for: moment) }
        if need == .couchScroll, peeking { return ["……我们今天，真的不动了吗。", "那个包……算了。", "……再一个。"] }
        if need == .boxingWarmup { return ["今天网球。……拍子带好了。", "……手腕转好了。", "先拍两下球。"] }
        if need == .couchScroll { return ["……再一个。", "这个有点好笑。", "你也在刷？"] }
        if let life { return lines(for: life) }
        return switch mode {
        case .work: ["……开始了。", "お疲れ。……先说了。", "……在听。"]
        case .chill: ["……回来了。", "热饮，分你一口。", "まあね。"]
        case .boxing: ["正手，反手。", "……今天手感不错。", "头带系好了。"]
        case .money: ["……在批。", "还剩一摞。", "……"]
        case nil: ["……先选一个吧。"]
        }
    }

    private static func lines(for activity: CompanionActivity) -> [String] {
        switch activity {
        case .boxingAtGym: ["正手。……反手。", "……别看我，看球。", "这球，有点欠。"]
        case .gymSession: ["再一组。……你先。", "……比想的重。"]
        case .running: ["呼……别说话。", "……腿是你的。我陪着。"]
        case .gymDay: ["包在门口。……随你。", "今天也开着。……只是说说。"]
        case .runDay: ["鞋带系好了。你的呢。", "……先热个身。"]
        }
    }

    private static func lines(for moment: CompanionMoment) -> [String] {
        switch moment {
        case .slacking: ["……嘘。", "什么都没看见。"]
        case .drowsy: ["热奶茶，喝一口？", "……眼皮有点重。"]
        case .overtime: ["……还没结束啊。", "托腮，等着。"]
        case .gymInvite: ["……走吗。网球包拎好了。", "门就在那。……问问而已。"]
        case .heading: ["走了。", "包我拎着。"]
        case .vibeCoding: ["勾、勾、圈。", "……这题不对。", "红笔，再一支。"]
        // In flow she stays silent, like HAKU.
        case .flow: ["……"]
        case .lateCoding: ["……明天还在。"]
        case .shooting: ["光线不错。", "……这张可以。"]
        case .collapsed: ["……回来了。", "先让我窝五分钟。"]
        case .blanket: ["今天就这样吧。", "毯子分你一半。"]
        case .morning: ["……早。", "发圈去哪了。"]
        case .timeToLeave: ["……该走了。", "嗯。"]
        case .stiff: ["……腰。", "起来。我先起了。", "ちょっと休憩。"]
        case .packingUp: ["快了。", "……在收。"]
        }
    }

    private static func lines(for life: IdleLife) -> [String] {
        switch life {
        case .nap: ["……干嘛。", "再睡五分钟。"]
        case .handheld: ["……这关快过了。", "不给你玩。"]
        case .snack: ["……没吃。", "什么零食。没看见。"]
        case .drawing: ["没画什么。", "……不许看。"]
        case .practice: ["……没在练。", "活动一下手腕而已。"]
        case .tidying: ["周日了，收一收。", "……让一让。"]
        }
    }

    /// What KURO says after a workout.
    static func celebration(_ kind: WorkoutSummary.Kind) -> String {
        switch kind {
        case .boxing: "……还行。"
        case .running: "……真跑完了。"
        case .strength: "……不错。"
        case .other: "嗯。……还行。"
        }
    }

    /// What KURO says when unboxing the item with `itemID`.
    static func unlock(_ itemID: String) -> String {
        ShopItem.item(itemID)?.keepsake != nil ? "……给你的。不是特意挑的。" : "……那就收下了。"
    }
}
