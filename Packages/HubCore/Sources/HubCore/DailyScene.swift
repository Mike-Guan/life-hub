import Foundation

// PM scene library v0 (Mike approved the preview 2026-10-05). Rules only (T0): keywords in the title,
// matched on the device. The title never leaves the phone and never shows on the Lock Screen.
/// What HAKU acts out for a Daily task, picked from words in its title.
public enum DailyScene: String, Codable, CaseIterable, Sendable {
    case coffee
    case meal
    case meeting
    case call
    case grocery
    case shopping
    case cook
    case haircut
    case doctor
    case gym
    case run
    case stroll
    case photo
    case friends

    // In the library's order: when a title matches several scenes, the first one wins.
    private static let keywords: [(DailyScene, [String])] = [
        (.coffee, ["咖啡", "拿铁", "星巴克", "カフェ", "コーヒー", "coffee", "cafe"]),
        (.meal, [
            "吃饭", "午饭", "晚饭", "餐厅", "ランチ", "ディナー", "lunch", "dinner",
            "聚餐", "喝酒", "居酒屋", "饮み会", "飲み会", "drinks",
        ]),
        (.meeting, ["会议", "开会", "例会", "1on1", "会議", "mtg", "meeting", "sync"]),
        (.call, ["电话", "通话", "面试", "電話", "call", "zoom"]),
        (.grocery, ["买菜", "超市", "スーパー", "grocery"]),
        (.shopping, ["购物", "逛街", "买衣服", "优衣库", "无印", "買い物", "ショッピング", "shopping"]),
        (.cook, ["做饭", "做菜", "备餐", "料理", "自炊", "cook", "meal prep"]),
        (.haircut, ["理发", "剪头", "美容院", "カット", "haircut"]),
        (.doctor, ["医院", "看病", "牙医", "体检", "病院", "歯医者", "doctor", "dentist"]),
        (.gym, ["健身", "练腿", "练胸", "ジム", "筋トレ", "gym", "workout"]),
        (.run, ["跑步", "5km", "晨跑", "ランニング", "run"]),
        (.stroll, ["散步", "遛弯", "晒太阳", "散歩", "walk"]),
        (.photo, ["拍照", "外拍", "约拍", "人像", "撮影", "shoot", "photo"]),
        (.friends, ["见朋友", "约", "碰面", "友達", "会う", "meet", "friends"]),
    ]

    /// The first scene whose keywords appear in `title`, ignoring case, or nil when none do.
    public init?(title: String) {
        let text = title.lowercased()
        guard let match = Self.keywords.first(where: { $0.1.contains { text.contains($0) } })?.0 else {
            return nil
        }
        // PM: a shopping title that mentions vegetables is a grocery run.
        self = match == .shopping && text.contains("菜") ? .grocery : match
    }
}
