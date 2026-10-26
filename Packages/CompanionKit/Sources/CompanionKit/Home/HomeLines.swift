import HubCore

// UI 三组 家台词 v1 (2026-10-26): the second character says her own lines in the home, one for one with HAKU's.
// The text is the Chinese key; translations live in the character's table (Haku, Kuro).
/// What a character says on the home page's card.
struct HomeLines: Sendable {
    private let isKuro: Bool

    /// - Parameter persona: whose lines.
    init(_ persona: Persona) {
        isKuro = persona == .kuro
    }

    // The next four are HAKU's for both until UI 三组 writes hers.
    /// The first line when the home opens.
    var arrive: String { "……来了。随便坐。" }
    /// Picked up.
    var lift: String { "喂。" }
    /// Dropped somewhere.
    var drop: String { "……放我下来就行。" }
    /// Tapped three times within two seconds.
    var annoyed: String { "够了。" }

    var desk: String { isKuro ? "……坐一下。不一定在弄。" : "坐一会儿。不一定干活。" }
    var sofa: String { isKuro ? "这边是我的位置。" : "沙发是我的。" }
    var sofaLow: String { isKuro ? "……这边是我的。今天没电了。" : "沙发是我的。今天电量不够。" }
    var bed: String { "……再五分钟。" }
    var bag: String { isKuro ? "正手，反手。" : "左、右、左。" }
    var bench: String { isKuro ? "……推两下。不数。" : "推几下。不数。" }
    var windowNight: String { isKuro ? "对面还亮着灯。" : "楼下的灯还亮着。" }
    var windowDay: String { isKuro ? "今天光线不错。" : "窗外挺亮。" }
    var wardrobe: String { isKuro ? "……今天穿哪件呢。" : "穿什么都一样帅。" }
    var shop: String { isKuro ? "罐子是你的。……我只是看看。" : "罐子是你的。我只是看着。" }
    var shelf: String { isKuro ? "这些，都是真的有过的。" : "这些都是真的发生过的。" }

    // Mode-change formats; `%@` is the card's name.
    var work: String { isKuro ? "%@。……开始了。" : "%@。脑子开机中。" }
    var chill: String { isKuro ? "%@。……回来了。" : "%@。今天到此为止。" }
    var boxBag: String { isKuro ? "%@。先打几下沙袋。" : "%@。沙袋先挨几下。" }
    var boxAir: String { isKuro ? "%@。没沙袋……打空气也行。" : "%@。没沙袋，打空气也行。" }
    var benchMode: String { isKuro ? "%@。推两下。" : "%@。推几下。" }
    var goingOut: String { isKuro ? "%@。包拎好了。" : "%@。准备出门。" }
    var money: String { isKuro ? "%@。……别吵，也别走。" : "%@。别打扰，也别走。" }

    // Lines for a tap on the character, by where she is.
    var atWork: [String] { isKuro ? ["……在听。", "快好了。"] : ["在忙。", "……别催。"] }
    var atSide: [String] { isKuro ? ["……不许看。", "一件一件来。"] : ["别看，还没做完。", "就差一点。可能。"] }
    var atSofa: [String] { isKuro ? ["今天就这样吧。", "毯子分你一半。"] : ["什么也不想做，这也算一种状态。", "遥控器在你那边。"] }
    var atRest: [String] { ["……再五分钟。", "zzz"] }
    var atBox: [String] { isKuro ? ["正手。……反手。", "……别看我，看球。"] : ["左、右、左。", "沙袋没惹我，是我今天比较硬。"] }
    var atBench: [String] { isKuro ? ["……比想的重。", "重量？不告诉你。"] : ["推起来，放下去。就这样。", "重量？不告诉你。"] }
    var low: [String] { isKuro ? ["……没电了。", "……干嘛。"] : ["电量不太够。", "……干嘛。"] }
    var idle: [String] {
        if isKuro {
            ["……干嘛。", "看我也不会多一罐哦。", "まあね。", "今天也没什么特别的。……挺好。"]
        } else {
            ["……干嘛。", "看我也不会多一罐。", "嗯。", "今天也没什么特别的。挺好。"]
        }
    }
}
