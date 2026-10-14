import Foundation

// Issue #273. The four `Mode` cases stay as slots, so stored mode changes need no migration: work,
// chill and money are the three common cards, boxing is the slot of the identity card the user picked.
/// A kind of identity card a user can pick for the fourth card.
public enum IdentityKind: String, Codable, CaseIterable, Sendable {
    case boxing
    case tennis
    case fitness
    case swimming
    case yoga
    case dance
    case ball
    case music
    case art
    case study
    case outdoor
    case ski

    // Kinds whose art is done for every character. A kind joins once UI finishes its art,
    // so a card that slips to a later release needs no other change.
    /// The kinds the picker shows.
    public static let released: [IdentityKind] = [.boxing, .tennis]

    /// Whether the picker shows this kind.
    public var isReleased: Bool { Self.released.contains(self) }

    /// The card's name.
    public var title: String { titleKey.localized }

    private var titleKey: String {
        switch self {
        case .boxing: "拳击日"
        case .tennis: "网球日"
        case .fitness: "健身"
        case .swimming: "游泳"
        case .yoga: "瑜伽"
        case .dance: "跳舞"
        case .ball: "球类"
        case .music: "乐器"
        case .art: "画画手作"
        case .study: "自习"
        case .outdoor: "户外"
        case .ski: "滑雪"
        }
    }

    /// The activity's name without 日, for sentences such as the countdown and place names.
    public var activity: String {
        switch self {
        case .boxing: "拳击".localized
        case .tennis: "网球".localized
        default: title
        }
    }

    /// The card's short English code, for the home header.
    public var code: String {
        switch self {
        case .boxing: "BOXING"
        case .tennis: "TENNIS"
        case .fitness: "GYM"
        case .swimming: "SWIM"
        case .yoga: "YOGA"
        case .dance: "DANCE"
        case .ball: "BALL"
        case .music: "MUSIC"
        case .art: "ART"
        case .study: "STUDY"
        case .outdoor: "OUTDOOR"
        case .ski: "SKI"
        }
    }

    // 卡片标语与代码 v0 §2. Cards still without lines say their name.
    /// The line under the home card in `persona`'s voice.
    public func tagline(for persona: Persona) -> String {
        let lines: (haku: String, kuro: String)?
        switch self {
        case .boxing: lines = ("头带系紧", "拳套系好了")
        case .tennis: lines = ("球拍拿好", "拍线刚调过")
        case .fitness: lines = ("包背好了", "水瓶装满了")
        case .study: lines = ("书摊开了", "眼镜戴上")
        case .art: lines = ("本子翻开了", "笔在手上")
        case .outdoor: lines = ("鞋带系紧", "慢慢走")
        case .swimming: lines = ("泳帽塞好了", "毛巾带上")
        case .yoga: lines = ("垫子卷好了", "呼——吸")
        case .ball: lines = ("球打满气了", "帮你看着")
        case .dance, .music, .ski: lines = nil
        }
        guard let lines else { return String(format: "%@中".localized, title) }
        return (persona == .kuro ? lines.kuro : lines.haku).localized
    }

    // 卡片标语与代码 v0 §2: the invite on the learned identity day. Cards still without one use a plain line.
    /// The identity day's invite in `persona`'s voice.
    public func invite(for persona: Persona) -> String {
        let lines: (haku: String, kuro: String)?
        switch self {
        case .boxing: lines = ("拳套我都戴好了，你随意啊。", "……拳套系好了。去吗。")
        case .tennis: lines = ("球拍在门口。去不去随你。", "今天网球。……拍子带好了。")
        case .fitness: lines = ("包我背好了。", "……包在门口。")
        case .study: lines = ("书我装好了。", "……今天也去看会儿书？")
        case .art: lines = ("速写本带上了。", "……今天去画吗。")
        case .outdoor: lines = ("背包我收好了。", "……今天出去走走？")
        case .swimming: lines = ("泳帽我找到了。", "……毛巾带了吗。")
        case .yoga: lines = ("垫子卷好了。", "……今天去拉伸吗。")
        case .ball: lines = ("球我打好气了。", "……今天去打球吗。")
        case .dance, .music, .ski: lines = nil
        }
        guard let lines else {
            return persona == .kuro ? "……今天去吗。".localized : String(format: "今天%@，我准备好了。".localized, title)
        }
        return (persona == .kuro ? lines.kuro : lines.haku).localized
    }

    // 第 1 批、第 2 批、顺延身份卡 台词与待机 v0: three tap lines per card and character.
    /// What the character says in this card's mode, in `persona`'s voice.
    public func lines(for persona: Persona) -> [String] {
        let lines: (haku: [String], kuro: [String])
        switch self {
        case .boxing: lines = (["……别碰，手带刚缠好。", "打完再说。", "拳套有点味道。不是我的问题。"], ["……别闹。", "等一下，在系。", "……你看什么。"])
        case .tennis: lines = (["球拍比我想的重。还是重。", "……别抢。", "捡球的不是我。"], ["……拍子别碰。", "等我颠完。", "……嗯。"])
        case .fitness: lines = (["……我数，你练。", "……这个不重。", "别看我，看镜子。"], ["……我在这儿。", "数到几了？", "……慢点。"])
        case .study: lines = (["安静。", "……这页我看过了。", "你看你的，我看我的。"], ["……嘘。", "这里有点难。", "……翻一页。"])
        case .art: lines = (["……袖子挽起来了。", "……还没画完。", "不给看。"], ["……画好了给你看。", "还差一点。", "……别催。"])
        case .outdoor: lines = (["……走这么远。", "包有点沉。不是抱怨。"], ["……慢慢走。", "这边好安静。", "……我走慢一点。"])
        case .swimming: lines = (["我不下水。", "泳帽？不戴。", "毛巾在我这儿。"], ["……吹风机我拿来了。", "……我在岸上等。", "……嗯。"])
        case .yoga: lines = (["这个姿势我做不了。", "……别笑。", "垫子是你的，我坐边上。"], ["……我也试试。", "呼——", "……慢一点。"])
        case .ball: lines = (["球别往我这边打。", "……我就看看。", "谁赢了？算了，不重要。"], ["……我帮你看着。", "……我在这儿看。", "……嗯。"])
        case .dance: lines = (["我刚才没跳。", "……节奏不错。", "别录。"], ["……嘿嘿。", "再来一遍？", "……不许看。"])
        case .music: lines = (["……刚才那个音不算。", "别吵，在数拍。", "我只会这一段。"], ["……嘘，在听。", "这段好难。", "……再一遍。"])
        case .ski: lines = (["冷。不是抱怨。", "……我坐缆车就行。", "雪镜起雾了。"], ["……好冷。", "手好冰。", "……再滑一次？"])
        }
        return (persona == .kuro ? lines.kuro : lines.haku).map(\.localized)
    }

    /// Whether the card is a sport.
    public var isSport: Bool {
        switch self {
        case .music, .art, .study: false
        default: true
        }
    }

    /// The SF Symbol for the card's mode button.
    public var symbol: String {
        switch self {
        case .boxing: "figure.boxing"
        case .tennis: "figure.tennis"
        case .fitness: "dumbbell.fill"
        case .swimming: "figure.pool.swim"
        case .yoga: "figure.yoga"
        case .dance: "figure.dance"
        case .ball: "basketball.fill"
        case .music: "guitars.fill"
        case .art: "paintpalette.fill"
        case .study: "book.fill"
        case .outdoor: "figure.hiking"
        case .ski: "figure.skiing.downhill"
        }
    }

    // Skiing has no group of its own yet: Health's snow sports fall under `.outdoor` with hiking,
    // so a hike would switch to the ski card. It gets its workout kind with the switching rules.
    /// The watch workouts that switch to this card. Empty when only a place or a tap does.
    public var workouts: Set<WorkoutSummary.Kind> {
        switch self {
        case .boxing: [.boxing]
        case .tennis: [.racket]
        case .fitness: [.strength]
        case .swimming: [.swimming]
        case .yoga: [.yoga]
        case .dance: [.dance]
        case .ball: [.ball]
        case .outdoor: [.outdoor]
        case .music, .art, .study, .ski: []
        }
    }
}

/// Something in Chill the user picked for the character to act out. Only things the app can sense.
public enum ChillActivity: String, Codable, CaseIterable, Sendable {
    case fitness
    case running
    case walking
    case yoga
    case cycling
    case swimming
    case ball
    case shopping

    /// The name in the picker.
    public var title: String { titleKey.localized }

    private var titleKey: String {
        switch self {
        case .fitness: "健身"
        case .running: "跑步"
        case .walking: "散步晒太阳"
        case .yoga: "瑜伽拉伸"
        case .cycling: "骑车"
        case .swimming: "游泳"
        case .ball: "球类"
        case .shopping: "买菜逛街"
        }
    }
}

/// The user's four cards: names for the common ones, the picked identity card, Chill activities and
/// the 副业 states. Places say which card they switch to themselves (`HubPlace.action`).
public struct ModeCards: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    static let defaultsKey = "modeCards"

    // UI, 2026-10-13: the watch shows the name in the clock row at full size.
    /// The widest card name that fits the watch's clock row: 4 Chinese characters or 8 Latin letters.
    public static let nameWidth = 8
    /// How many 副业 states the user can pick.
    public static let sideStateLimit = 3

    public var schemaVersion: Int
    // Keyed by `Mode` raw value, so a slot this build doesn't know is kept, not fatal.
    /// The user's own names for the common cards. A missing name shows the default.
    public var names: [String: String]
    // Kept as the raw name, so an older build that doesn't know the kind writes it back unchanged.
    /// The identity card's raw `IdentityKind` name, `nil` when the user picked none.
    public var identityName: String?
    /// The Chill activities the character acts out.
    public var chill: Set<ChillActivity>
    /// The 副业 states tapping the character cycles through, in order. Never empty.
    public var sideStates: [SideHustle]
    // DW-02: an older build keeps the values only a newer one knows and writes them back.
    var unknownChill: [String] = []
    var unknownSideStates: [String] = []
    // True while `sideStates` holds only the fallback for a list this build couldn't read.
    var sideStatesFilledIn = false

    public init(
        names: [String: String] = [:],
        identity: IdentityKind? = nil,
        chill: Set<ChillActivity> = Set(ChillActivity.allCases),
        sideStates: [SideHustle] = [.vibeCoding]
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.names = names
        self.identityName = identity?.rawValue
        self.chill = chill
        self.sideStates = sideStates.isEmpty ? [.vibeCoding] : sideStates
    }

    // Users from before #273 keep what their character had: HAKU's boxing, the second character's
    // tennis, every Chill activity and the three 副业 states.
    /// The cards an existing install had with `persona`.
    public static func legacy(for persona: Persona) -> ModeCards {
        // KURO's 副业 was called 备课 before the cards; it is her name for it now.
        ModeCards(
            names: persona == .kuro ? [Mode.money.rawValue: "备课"] : [:],
            identity: persona == .kuro ? .tennis : .boxing,
            sideStates: [.vibeCoding, .shooting, .operating]
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, names
        case identityName = "identity"
        case chill, sideStates
    }

    /// Decodes the cards; missing fields and values this build doesn't know fall back to the defaults.
    /// - Throws: `DecodingError` when the data is not an object.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = (try? values.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? 1
        names = (try? values.decodeIfPresent([String: String].self, forKey: .names)) ?? [:]
        identityName = try? values.decodeIfPresent(String.self, forKey: .identityName)
        let chillNames = try? values.decodeIfPresent([String].self, forKey: .chill)
        chill = chillNames.map { Set($0.compactMap(ChillActivity.init(rawValue:))) } ?? Set(ChillActivity.allCases)
        unknownChill = (chillNames ?? []).filter { ChillActivity(rawValue: $0) == nil }
        let sideNames = (try? values.decodeIfPresent([String].self, forKey: .sideStates)) ?? []
        let states = sideNames.compactMap(SideHustle.init(rawValue:))
        sideStates = states.isEmpty ? [.vibeCoding] : states
        sideStatesFilledIn = states.isEmpty && !sideNames.isEmpty
        unknownSideStates = sideNames.filter { SideHustle(rawValue: $0) == nil }
    }

    /// Encodes the cards, with the values this build doesn't know after the known ones.
    /// - Throws: `EncodingError` when a value can't be encoded.
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(names, forKey: .names)
        try values.encodeIfPresent(identityName, forKey: .identityName)
        let chillNames = ChillActivity.allCases.filter(chill.contains).map(\.rawValue)
        try values.encode(chillNames + unknownChill, forKey: .chill)
        let known = sideStatesFilledIn && sideStates == [.vibeCoding] ? [] : sideStates.map(\.rawValue)
        try values.encode(known + unknownSideStates, forKey: .sideStates)
    }

    /// The identity card, `nil` when the user picked none or this build doesn't know it.
    public var identity: IdentityKind? {
        get { identityName.flatMap(IdentityKind.init(rawValue:)) }
        set { identityName = newValue?.rawValue }
    }

    /// The name of the card in `mode`'s slot: the user's name, else the identity card's, else the
    /// character's default.
    public func title(for mode: Mode, persona: Persona) -> String {
        if let name = names[mode.rawValue] { return name }
        if mode == .boxing, let identity { return identity.title }
        return mode.title(for: persona)
    }

    /// The identity slot's activity for sentences, without 日: the picked card's, else the character's default.
    public func activity(for persona: Persona) -> String {
        (identity ?? Self.legacy(for: persona).identity ?? .boxing).activity
    }

    /// The card's short English code: the identity card's own, else the character's default.
    public func code(for mode: Mode, persona: Persona) -> String {
        guard let identity = pickedIdentity(for: mode, persona: persona) else { return mode.code(for: persona) }
        return identity.code
    }

    /// The line under the home card: the identity card's own in the identity slot, else the mode's.
    public func tagline(for mode: Mode, persona: Persona) -> String {
        guard mode == .boxing, let identity else { return mode.tagline(for: persona) }
        return identity.tagline(for: persona)
    }

    // 台词 泛化修改 v0 §1: lines about a sports bag are only for users who do sport.
    /// Whether the user picked a sport card or a sporty Chill activity.
    public var isSporty: Bool {
        let sporty: Set<ChillActivity> = [.fitness, .running, .yoga, .cycling, .swimming, .ball]
        return identity?.isSport == true || !chill.isDisjoint(with: sporty)
    }

    // 活动分类 v1 §4: without an identity card there is no empty slot.
    /// The modes the user can switch to: all four, or the three common cards without an identity card.
    public var modes: [Mode] {
        identityName == nil ? Mode.allCases.filter { $0 != .boxing } : Mode.allCases
    }

    /// The identity card in `mode`'s slot when it differs from `persona`'s default one, else `nil`.
    public func pickedIdentity(for mode: Mode, persona: Persona) -> IdentityKind? {
        guard mode == .boxing, let identity, identity != Self.legacy(for: persona).identity else { return nil }
        return identity
    }

    /// Renames the common card in `mode`'s slot, cut to `nameWidth`; an empty name restores the default.
    /// - Returns: `false`, changing nothing, for the identity slot.
    @discardableResult
    public mutating func rename(_ mode: Mode, to name: String) -> Bool {
        guard mode != .boxing else { return false }
        let trimmed = Self.fitted(name.trimmingCharacters(in: .whitespacesAndNewlines))
        names[mode.rawValue] = trimmed.isEmpty ? nil : trimmed
        return true
    }

    /// How wide `text` is on the watch: ASCII counts 1, anything else 2.
    public static func width(of text: String) -> Int {
        text.reduce(0) { $0 + ($1.isASCII ? 1 : 2) }
    }

    /// `text` cut to at most `nameWidth`.
    public static func fitted(_ text: String) -> String {
        var result = ""
        for character in text {
            guard width(of: result + String(character)) <= nameWidth else { break }
            result.append(character)
        }
        return result
    }

    /// Sets the 副业 states, keeping the first `sideStateLimit` distinct ones.
    /// - Returns: `false`, changing nothing, when `states` is empty.
    @discardableResult
    public mutating func pickSideStates(_ states: [SideHustle]) -> Bool {
        var picked: [SideHustle] = []
        for state in states where !picked.contains(state) && picked.count < Self.sideStateLimit {
            picked.append(state)
        }
        guard !picked.isEmpty else { return false }
        sideStates = picked
        // The user picked from what this build shows.
        unknownSideStates = []
        sideStatesFilledIn = false
        return true
    }

    /// The 副业 state after `state` when the user taps the character. A state not picked goes to the first.
    public func next(after state: SideHustle) -> SideHustle {
        guard let index = sideStates.firstIndex(of: state) else { return sideStates[0] }
        return sideStates[(index + 1) % sideStates.count]
    }

    /// The identity card a workout of `kind` switches to, `nil` when the picked card has no such workout.
    public func card(for kind: WorkoutSummary.Kind) -> IdentityKind? {
        guard let identity, identity.workouts.contains(kind) else { return nil }
        return identity
    }

    // PM #20: a new install starts with the generic cards and no identity card. Saving them on the first
    // launch keeps an install that later gains records from turning into the legacy cards.
    /// Saves the first cards when none are saved: `persona`'s cards from before Issue #273 for an install
    /// that already has records, else the generic ones.
    public static func adopt(in defaults: UserDefaults, persona: Persona, existingInstall: Bool) {
        guard defaults.data(forKey: defaultsKey) == nil else { return }
        (existingInstall ? legacy(for: persona) : ModeCards()).store(in: defaults)
    }

    /// The cards saved in `defaults`, or the generic cards when none are saved.
    public static func current(in defaults: UserDefaults, persona: Persona) -> ModeCards {
        stored(in: defaults) ?? ModeCards()
    }

    /// The cards saved in `defaults`, or `nil` when none are saved or they can't be read.
    public static func stored(in defaults: UserDefaults) -> ModeCards? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(ModeCards.self, from: data)
    }

    /// Saves the cards in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }
}
