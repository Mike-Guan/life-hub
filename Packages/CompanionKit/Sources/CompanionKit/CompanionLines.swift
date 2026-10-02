import HubCore

/// Tier 0 lines: fixed, per mode, no model. On-device generation comes later.
enum CompanionLines {
    static func lines(for mode: Mode?) -> [String] {
        switch mode {
        case .work: ["……在听。", "耳机不摘，谁都别找我。", "再撑一会儿就下班。"]
        case .chill: ["今天辛苦了。", "Monster 第二罐不许开。", "买菜还是看剧？"]
        case .boxing: ["来，左右直拳。", "今天把沙袋打哭。", "头带系紧了吗？"]
        case .money: ["¥¥ 在路上。", "这周的样片拍了吗？", "发一条，就一条。"]
        case nil: ["先选一个 mode 吧。"]
        }
    }
}
