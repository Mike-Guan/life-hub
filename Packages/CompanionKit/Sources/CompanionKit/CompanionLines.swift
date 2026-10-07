import HubCore

// Tier 0: no model. On-device generation comes later.
// Voice: HAKU, a deadpan roommate who secretly cares.
/// Fixed companion lines per mode, need and idle bit.
enum CompanionLines {
    static func lines(
        for mode: Mode?,
        need: CompanionNeed? = nil,
        peeking: Bool = false,
        life: IdleLife? = nil,
        activity: CompanionActivity? = nil,
        moment: CompanionMoment? = nil,
        persona: Persona = .haku
    ) -> [String] {
        if persona == .kuro {
            return KuroBubbleLines.lines(
                for: mode,
                need: need,
                peeking: peeking,
                life: life,
                activity: activity,
                moment: moment
            )
        }
        if let activity { return lines(for: activity) }
        if let moment { return lines(for: moment) }
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

    private static func lines(for activity: CompanionActivity) -> [String] {
        switch activity {
        case .boxingAtGym: ["左、左、右。", "……别看我，看沙袋。", "今天的沙袋有点欠揍。"]
        case .gymSession: ["再来一组。……你先。", "哑铃比我想的重。"]
        case .running: ["呼……别跟我说话。", "腿是你的，我只是陪跑。"]
        case .gymDay: ["包我都背好了。你随意啊。", "健身房今天也开着。……我只是说说。"]
        case .runDay: ["鞋带我系好了。你的呢？", "今天是跑步日。……我先热个身。"]
        }
    }

    private static func lines(for moment: CompanionMoment) -> [String] {
        switch moment {
        case .slacking: ["老板在看。我也在看。", "嘘。"]
        case .drowsy: ["来一罐？", "眼皮有点重……"]
        case .overtime: ["灵魂已经下班了。", "……我只是趴一下。"]
        case .gymInvite: ["去不去？我包都背好了。", "门就在这。……我只是说说。"]
        case .heading: ["走了走了。", "包我背着，你走路就行。"]
        case .vibeCoding: ["能跑。别问为什么。", "这个 bug 不是我写的。", "再一罐。"]
        // In flow HAKU stays silent.
        case .flow: ["……"]
        case .lateCoding: ["代码明天还在。"]
        case .shooting: ["光线不错。", "这张可以。", "¥¥ 在路上。"]
        case .collapsed: ["你也活着回来了啊。", "……先让我趴五分钟。"]
        case .blanket: ["今天就这样吧。", "毯子分你一半。"]
        case .morning: ["又要上班了。", "耳机……耳机去哪了。"]
        case .timeToLeave: ["……公司还在等你。", "唉。"]
        case .stiff: ["……我腰要断了。", "起来。我先起了。", "ちょっと休憩。"]
        case .packingUp: ["快了。", "别催，在收。"]
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

    /// What the companion says after a workout: plays it cool.
    static func celebration(_ kind: WorkoutSummary.Kind, persona: Persona = .haku) -> String {
        if persona == .kuro { return KuroBubbleLines.celebration(kind) }
        return switch kind {
        case .boxing: "……其实还挺爽的。"
        case .running: "居然真跑完了。"
        case .strength: "不错嘛。"
        default: "哦。……不错嘛。"
        }
    }

    /// What the companion says when unboxing the item with `itemID`: a keepsake it pretends it didn't pick.
    static func unlock(_ itemID: String, persona: Persona = .haku) -> String {
        if persona == .kuro { return KuroBubbleLines.unlock(itemID) }
        return ShopItem.item(itemID)?.keepsake != nil ? "……给你的。才不是特意挑的。" : "买了？……那我就勉强收下了。"
    }

    /// The VoiceOver label for HAKU during the welcome back: its line, each card, and the cans opened.
    static func welcomeLabel(_ replay: ReturnReplay) -> String {
        var parts = ["HAKU：\(replay.line)"] + replay.cards.map(\.text)
        if replay.tier == .box, replay.cans > 0 { parts.append("\(replay.cans) 罐，一起打开。") }
        return parts.joined(separator: " ")
    }

    /// The VoiceOver label for HAKU.
    static func accessibilityLabel(
        mode: Mode?,
        need: CompanionNeed?,
        peeking: Bool = false,
        life: IdleLife? = nil,
        activity: CompanionActivity? = nil,
        moment: CompanionMoment? = nil,
        bedtime: Bedtime
    ) -> String {
        if bedtime == .on { return "HAKU，困了" }
        if let activity { return "HAKU，\(doing(activity))" }
        if let moment { return "HAKU，\(state(moment))" }
        if need == .couchScroll, peeking { return "HAKU，瘫着刷手机，偷看门口的运动包" }
        if need == .boxingWarmup { return "HAKU，戴着拳套在热身" }
        if need == .couchScroll { return "HAKU，瘫着刷手机" }
        if let life { return "HAKU，\(pastime(life))" }
        return mode.map { "HAKU，\($0.title)" } ?? "HAKU"
    }

    private static func doing(_ activity: CompanionActivity) -> String {
        switch activity {
        case .boxingAtGym: "在拳馆打沙袋"
        case .gymSession: "在健身房举哑铃"
        case .running: "在跑步"
        case .gymDay: "背好了运动包，等着去健身房"
        case .runDay: "拿着跑鞋在热身"
        }
    }

    private static func state(_ moment: CompanionMoment) -> String {
        switch moment {
        case .slacking: "从电脑屏幕后面探头"
        case .drowsy: "犯困，开了一罐 Monster"
        case .overtime: "加班，趴在桌上"
        case .gymInvite: "背着运动包站在门口"
        case .heading: "背着运动包出发了"
        case .vibeCoding: "穿着连帽衫在写代码"
        case .flow: "写代码写进了心流"
        case .lateCoding: "熬夜写代码，很困"
        case .shooting: "在忙副业的拍摄"
        case .collapsed: "下班回家，趴在沙发扶手上"
        case .blanket: "裹着毯子瘫在沙发上"
        case .morning: "早上起来在刷牙"
        case .timeToLeave: "戴好耳机站在门口，敲着手表"
        case .stiff: "坐太久了，扭扭腰，捶捶背"
        case .packingUp: "快下班了，收好电脑，看着手表等"
        }
    }

    private static func pastime(_ life: IdleLife) -> String {
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
