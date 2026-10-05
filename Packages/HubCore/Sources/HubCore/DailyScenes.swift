import Foundation

/// What HAKU acts out for a Daily task whose title names it, in place of the category prop.
public enum DailyScene: String, Codable, CaseIterable, Sendable {
    case coffee
    /// Eating out.
    case meal
    /// Drinks or a group dinner.
    case drinks
    case meeting
    case call
    case grocery
    /// Clothes, appliances, browsing shops.
    case shopping
    case cook
    case haircut
    /// Doctor or dentist.
    case doctor
    case gym
    case run
    case walk
    case photo
    case friends
}

// Scene library v0, P1 (Mike approved 2026-10-05 14:46Z, PRD section 15). Kept as data so scenes and
// Mike's corrections can be added later. Titles are matched on the phone only.
/// One row of the scene table: a title with any of `keywords` and none of `excludes` gets `scene`.
public struct SceneRule: Codable, Equatable, Sendable {
    public var scene: DailyScene
    public var keywords: [String]
    public var excludes: [String]

    public init(_ scene: DailyScene, _ keywords: [String], excludes: [String] = []) {
        self.scene = scene
        self.keywords = keywords
        self.excludes = excludes
    }
}

/// The scene table, matched top to bottom.
public struct SceneTable: Codable, Equatable, Sendable {
    public var rules: [SceneRule]

    public init(rules: [SceneRule]) {
        self.rules = rules
    }

    // Grocery comes before shopping: anything with 超市, スーパー or 菜 is grocery, but 做菜 is cooking.
    // 预约 (a booking) is not 约 (meeting up).
    // English words are short, so they only match whole words: "brunch" is not "run".
    /// The P1 scenes.
    public static let standard = SceneTable(rules: [
        SceneRule(.coffee, ["咖啡", "拿铁", "星巴克", "カフェ", "コーヒー", "coffee", "cafe"]),
        SceneRule(.meal, ["吃饭", "午饭", "晚饭", "餐厅", "ランチ", "ディナー", "lunch", "dinner"]),
        SceneRule(.drinks, ["聚餐", "喝酒", "居酒屋", "饮み会", "飲み会", "drinks", "bar"]),
        SceneRule(.meeting, ["会议", "开会", "例会", "1on1", "会議", "MTG", "meeting", "sync"]),
        SceneRule(.call, ["电话", "通话", "面试", "電話", "call", "zoom"]),
        SceneRule(.grocery, ["买菜", "超市", "スーパー", "菜", "grocery"], excludes: ["做菜"]),
        SceneRule(.shopping, ["购物", "逛街", "买衣服", "优衣库", "无印", "買い物", "ショッピング", "shopping"]),
        SceneRule(.cook, ["做饭", "做菜", "备餐", "料理", "自炊", "cook", "meal prep"]),
        SceneRule(.haircut, ["理发", "剪头", "美容院", "カット", "haircut"]),
        SceneRule(.doctor, ["医院", "看病", "牙医", "体检", "病院", "歯医者", "doctor", "dentist"]),
        SceneRule(.gym, ["健身", "练腿", "练胸", "ジム", "筋トレ", "gym", "workout"]),
        SceneRule(.run, ["跑步", "5km", "晨跑", "ランニング", "run"]),
        SceneRule(.walk, ["散步", "遛弯", "晒太阳", "散歩", "walk"]),
        SceneRule(.photo, ["拍照", "外拍", "约拍", "人像", "撮影", "shoot", "photo"]),
        SceneRule(.friends, ["见朋友", "约", "碰面", "友達", "会う", "meet", "friends"], excludes: ["预约"]),
    ])

    /// The scene of the first rule `title` matches, ignoring case and full or half width.
    /// - Returns: `nil` when no rule matches.
    public func scene(for title: String) -> DailyScene? {
        let text = Self.fold(title)
        let matches = { (word: String) in Self.contains(text, Self.fold(word)) }
        return rules.first { $0.keywords.contains(where: matches) && !$0.excludes.contains(where: matches) }?.scene
    }

    // Full-width letters and digits become half width and katakana stays full width, so "ＧＹＭ",
    // "gym" and "Gym" read the same and スーパー still matches.
    static func fold(_ text: String) -> String {
        var folded = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0xFF01...0xFF5E: folded.append(Unicode.Scalar(scalar.value - 0xFEE0) ?? scalar)
            case 0x3000: folded.append(" ")
            default: folded.append(scalar)
            }
        }
        return String(folded).lowercased()
    }

    private static func contains(_ text: String, _ word: String) -> Bool {
        guard word.allSatisfy(\.isASCII) else { return text.contains(word) }
        var from = text.startIndex
        while let found = text.range(of: word, range: from..<text.endIndex) {
            let before = found.lowerBound == text.startIndex ? nil : text[text.index(before: found.lowerBound)]
            let after = found.upperBound == text.endIndex ? nil : text[found.upperBound]
            if !isWordPart(before), !isWordPart(after) { return true }
            from = text.index(after: found.lowerBound)
        }
        return false
    }

    private static func isWordPart(_ character: Character?) -> Bool {
        guard let character else { return false }
        return character.isASCII && (character.isLetter || character.isNumber)
    }
}
