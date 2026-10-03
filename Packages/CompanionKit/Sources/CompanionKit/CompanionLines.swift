import HubCore

// Tier 0: no model. On-device generation comes later.
/// Fixed companion lines per mode and need.
enum CompanionLines {
    static func lines(for mode: Mode?, need: CompanionNeed? = nil) -> [String] {
        if need == .boxingWarmup { return ["拳套戴好了，就差你。", "十点开练，走吧。", "先跳两下热热身。"] }
        switch mode {
        case .work: ["……在听。", "耳机不摘，谁都别找我。", "再撑一会儿就下班。"]
        case .chill: ["今天辛苦了。", "Monster 第二罐不许开。", "买菜还是看剧？"]
        case .boxing: ["来，左右直拳。", "今天把沙袋打哭。", "头带系紧了吗？"]
        case .money: ["¥¥ 在路上。", "这周的样片拍了吗？", "发一条，就一条。"]
        case nil: ["先选一个 mode 吧。"]
        }
    }

    /// The VoiceOver label for RUNNER.
    static func accessibilityLabel(mode: Mode?, need: CompanionNeed?, bedtime: Bedtime) -> String {
        if bedtime == .on { return "RUNNER，困了" }
        if need == .boxingWarmup { return "RUNNER，戴着拳套在热身" }
        return mode.map { "RUNNER，\($0.title)" } ?? "RUNNER"
    }
}
