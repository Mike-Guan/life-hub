import HubCore

// Tier 0: no model. On-device generation comes later.
// Voice: HAKU, a deadpan roommate who secretly cares.
/// Fixed companion lines per mode, need and idle bit.
enum CompanionLines {
    static func lines(
        for mode: Mode?,
        need: CompanionNeed? = nil,
        peeking: Bool = false,
        life: IdleLife? = nil
    ) -> [String] {
        if need == .couchScroll, peeking { return ["所以……我们今天是真的不动了吗？", "那个包……算了。", "再刷五分钟。"] }
        if need == .boxingWarmup { return ["拳套我都戴好了，你随意啊。", "……我热身热得都快累了。", "先跳两下热热身。"] }
        if need == .couchScroll { return ["再刷五分钟。", "这条好好笑。", "你也在刷吗？"] }
        if let life { return lines(for: life) }
        return switch mode {
        case .work: ["又上班。", "人类为什么发明周一。", "……在听。"]
        case .chill: ["回来了？", "饭呢。", "Monster 第二罐不许开。"]
        case .boxing: ["来，左右直拳。", "今天把沙袋打哭。", "头带系紧了吗？"]
        case .money: ["¥¥ 在路上。", "数罐子中。", "……"]
        case nil: ["先选一个 mode 吧。"]
        }
    }

    private static func lines(for life: IdleLife) -> [String] {
        switch life {
        case .nap: ["……干嘛。", "再睡五分钟。"]
        case .handheld: ["别吵，这关快过了。", "……你也想玩？不给。"]
        case .snack: ["……没吃。", "什么零食，没看见。"]
        case .drawing: ["没画什么。", "不许看。"]
        case .practice: ["没在练。", "就是活动一下手。"]
        case .tidying: ["周日了，收拾一下。", "让一让，擦到你了。"]
        }
    }

    /// What HAKU says after a workout: plays it cool.
    static func celebration(_ kind: WorkoutSummary.Kind) -> String {
        switch kind {
        case .boxing: "……其实还挺爽的。"
        case .running: "居然真跑完了。"
        case .strength: "不错嘛。"
        case .other: "哦。……不错嘛。"
        }
    }

    /// The VoiceOver label for HAKU.
    static func accessibilityLabel(
        mode: Mode?,
        need: CompanionNeed?,
        peeking: Bool = false,
        life: IdleLife? = nil,
        bedtime: Bedtime
    ) -> String {
        if bedtime == .on { return "HAKU，困了" }
        if need == .couchScroll, peeking { return "HAKU，瘫着刷手机，偷看门口的运动包" }
        if need == .boxingWarmup { return "HAKU，戴着拳套在热身" }
        if need == .couchScroll { return "HAKU，瘫着刷手机" }
        if let life { return "HAKU，\(activity(life))" }
        return mode.map { "HAKU，\($0.title)" } ?? "HAKU"
    }

    private static func activity(_ life: IdleLife) -> String {
        switch life {
        case .nap: "在沙发角落睡着了"
        case .handheld: "在打游戏"
        case .snack: "在偷吃零食"
        case .drawing: "在偷偷画画"
        case .practice: "在偷偷练拳"
        case .tidying: "在拿抹布收拾房间"
        }
    }
}
