import HubCore
import Testing

@testable import CompanionKit

// 03 Product/companion/位置规划图 v0.md §4 steps 1, 2, 5 and 6. Every part has a spot: a place on the body or in
// the room and the thing it belongs to (gloves and their tape are one thing). In every state from
// `PlacementPoses`, a place holds at most one thing and no forbidden pair shows together. Figure parts (face,
// hair, jacket) and short effects (sparkles, lines, steam) are not checked.
//
// Conflicts that exist today are listed in `known` with where they were found. Each one must still happen:
// once it is fixed, its known issue stops being recorded and the test fails until the entry is removed.
/// Where each part of HAKU and KURO sits, and the conflicts the placement map tracks.
enum Placement {
    /// A place on the body or in the room, from the placement map §9.
    enum Place: String, Sendable {
        /// Face, hair, ears and the body itself: part of the character, not checked.
        case figure
        /// Short effects that float over everything: not checked.
        case fx
        case headTop, eyes, maskFace, mouth, cheek, earL, earR, earSideL, neck, torso, badge, lap, ponytail
        case handR, handL, handsFront
        case window, sill, door, pillow, corner1, corner2, deskR, scene, backdrop, bottom, wall
    }

    /// Where a part sits and the thing (the map's group) it belongs to.
    struct Spot: Hashable, Sendable {
        static let figure = Spot(.figure, "")
        static let fx = Spot(.fx, "")

        var place: Place
        var thing: String

        init(_ place: Place, _ thing: String) {
            self.place = place
            self.thing = thing
        }

        /// Whether two things in this place are a conflict.
        var isChecked: Bool { place != .figure && place != .fx }
    }

    // Generated from the placement map §9.1 and §9.2 (UI 一组, main c302979). Change the map first, then here.
    static let haku: [RunnerPart: Spot] = [
        .hairBack: .figure,
        .earL: .figure,
        .earR: .figure,
        .faceBase: .figure,
        .headBack: .figure,
        .hairFringe: .figure,
        .headband: Spot(.headTop, "headband"),
        .headset: Spot(.headTop, "耳机"),
        .hairTuft: Spot(.headTop, "hairTuft"),
        .cheerGoggles: Spot(.headTop, "cheerGoggles"),
        .bathTowel: Spot(.headTop, "bathTowel"),
        .cheerHelmet: Spot(.headTop, "cheerHelmet"),
        .eyesWork: Spot(.eyes, "眼睛"),
        .lidsWork: Spot(.eyes, "眼睛"),
        .eyebags: Spot(.eyes, "眼睛"),
        .browsWork: Spot(.eyes, "眼睛"),
        .eyesChill: Spot(.eyes, "眼睛"),
        .cateyeL: Spot(.eyes, "眼睛"),
        .cateyeR: Spot(.eyes, "眼睛"),
        .browsBox: Spot(.eyes, "眼睛"),
        .eyesMoney: Spot(.eyes, "眼睛"),
        .eyeGlint: Spot(.eyes, "眼睛"),
        .eyesSleepy: Spot(.eyes, "眼睛"),
        .eyesClosed: Spot(.eyes, "眼睛"),
        .eyeSwirlL: Spot(.eyes, "眼睛"),
        .eyeSwirlR: Spot(.eyes, "眼睛"),
        .maskUp: Spot(.maskFace, "面罩"),
        .panelLines: Spot(.maskFace, "面罩"),
        .maskStripes: Spot(.maskFace, "面罩"),
        .ledLine: Spot(.maskFace, "面罩"),
        .ledYen: Spot(.maskFace, "面罩"),
        .ledCode: Spot(.maskFace, "面罩"),
        .mouthSmile: Spot(.mouth, "嘴"),
        .mouthFang: Spot(.mouth, "嘴"),
        .mouthYawn: Spot(.mouth, "嘴"),
        .bandage: Spot(.cheek, "bandage"),
        .bathBlush: Spot(.cheek, "bathBlush"),
        .cupL: Spot(.earL, "耳机"),
        .earringNeon: Spot(.earL, "earringNeon"),
        .cheerEarTap: Spot(.earL, "cheerEarTap"),
        .cupR: Spot(.earR, "耳机"),
        .mic: Spot(.earR, "耳机"),
        .phoneEar: Spot(.earR, "phoneEar"),
        .peaceHand: Spot(.earR, "peaceHand"),
        .roomPc: Spot(.earSideL, "roomPc"),
        .maskDown: Spot(.neck, "面罩"),
        .maskStripesDown: Spot(.neck, "面罩"),
        .hoodCollar: Spot(.neck, "帽兜"),
        .hoodieStrings: Spot(.neck, "帽兜"),
        .jacket: Spot(.torso, "外套"),
        .stripeNeon: Spot(.torso, "外套"),
        .chainGold: Spot(.torso, "金链"),
        .coin: Spot(.torso, "金链"),
        .towel: Spot(.torso, "towel"),
        .apron: Spot(.torso, "apron"),
        .blanket: Spot(.lap, "blanket"),
        .monsterCan: Spot(.handR, "monsterCan"),
        .tapHand: Spot(.handR, "点按手"),
        .watchWrist: Spot(.handR, "点按手"),
        .onigiri: Spot(.handR, "onigiri"),
        .pencil: Spot(.handR, "pencil"),
        .cloth: Spot(.handR, "cloth"),
        .handWeight: Spot(.handR, "handWeight"),
        .spatula: Spot(.handR, "spatula"),
        .coffeeCup: Spot(.handR, "coffeeCup"),
        .chopsticks: Spot(.handR, "碗"),
        .stickyNote: Spot(.handR, "stickyNote"),
        .waveHand: Spot(.handR, "waveHand"),
        .clipArm: Spot(.handR, "推子"),
        .clipper: Spot(.handR, "推子"),
        .backFist: Spot(.handR, "backFist"),
        .runShoe: Spot(.handR, "runShoe"),
        .gloveR: Spot(.handR, "拳套"),
        .gloveTapeRight: Spot(.handR, "拳套"),
        .toothbrush: Spot(.handR, "toothbrush"),
        .camera: Spot(.handR, "camera"),
        .shopBag: Spot(.handR, "shopBag"),
        .cheerRacket: Spot(.handR, "cheerRacket"),
        .cheerBallHand: Spot(.handR, "球"),
        .cheerBall: Spot(.handR, "球"),
        .gloveL: Spot(.handL, "拳套"),
        .gloveTapeLeft: Spot(.handL, "拳套"),
        .scratchHand: Spot(.handL, "scratchHand"),
        .rubHand: Spot(.handL, "rubHand"),
        .cheekHand: Spot(.handL, "cheekHand"),
        .shampoo: Spot(.handL, "shampoo"),
        .rubTowelL: Spot(.handL, "擦汗毛巾"),
        .rubTowelR: Spot(.handL, "擦汗毛巾"),
        .phone: Spot(.handsFront, "手机"),
        .phoneFeed: Spot(.handsFront, "手机"),
        .phoneHand: Spot(.handsFront, "手机"),
        .phoneBack: Spot(.handsFront, "手机"),
        .handheld: Spot(.handsFront, "handheld"),
        .sketchbook: Spot(.handsFront, "sketchbook"),
        .laptop: Spot(.handsFront, "笔记本"),
        .laptopClosed: Spot(.handsFront, "笔记本"),
        .typingHands: Spot(.handsFront, "笔记本"),
        .macbook: Spot(.handsFront, "macbook"),
        .typeHandL: Spot(.handsFront, "macbook"),
        .typeHandR: Spot(.handsFront, "macbook"),
        .screenGlow: Spot(.handsFront, "macbook"),
        .dumbbell: Spot(.handsFront, "dumbbell"),
        .riceBowl: Spot(.handsFront, "碗"),
        .crateCans: Spot(.handsFront, "箱子"),
        .crateBox: Spot(.handsFront, "箱子"),
        .crateFlapL: Spot(.handsFront, "箱子"),
        .crateFlapR: Spot(.handsFront, "箱子"),
        .paperBagL: Spot(.handsFront, "纸袋"),
        .paperBagR: Spot(.handsFront, "纸袋"),
        .cheerStretchArms: Spot(.handsFront, "cheerStretchArms"),
        .sunlight: Spot(.window, "sunlight"),
        .door: Spot(.door, "door"),
        .pillow: Spot(.pillow, "pillow"),
        .roomPlant: Spot(.corner1, "roomPlant"),
        .roomBag: Spot(.corner1, "roomBag"),
        .heavyBag: Spot(.corner1, "heavyBag"),
        .toteBag: Spot(.corner1, "toteBag"),
        .gymBag: Spot(.corner1, "gymBag"),
        .runningShoes: Spot(.corner2, "runningShoes"),
        .deskMonitor: Spot(.deskR, "deskMonitor"),
        .canStackOne: Spot(.deskR, "罐子堆"),
        .canStackTwo: Spot(.deskR, "罐子堆"),
        .canStackThree: Spot(.deskR, "罐子堆"),
        .desk: Spot(.scene, "desk"),
        .sofaArm: Spot(.scene, "sofaArm"),
        .bathBubbles: Spot(.scene, "浴缸"),
        .rubberDuck: Spot(.scene, "浴缸"),
        .cheerMountains: Spot(.backdrop, "cheerMountains"),
        .walkDust: Spot(.bottom, "walkDust"),
        .cheerKick: Spot(.bottom, "cheerKick"),
        .cheerLegLines: Spot(.bottom, "cheerLegLines"),
        .speedLines: .fx,
        .sunIcon: .fx,
        .shopShine: .fx,
        .soul: .fx,
        .codeBits: .fx,
        .thumpLines: .fx,
        .sparkle: .fx,
        .dizzyStar: .fx,
        .musicNote: .fx,
        .zzz: .fx,
        .coffeeSteam: .fx,
        .blowLines: .fx,
        .talkDots: .fx,
        .cameraFlash: .fx,
        .waveArcs: .fx,
        .hairBits: .fx,
        .buzzLines: .fx,
        .ouchLines: .fx,
        .headSteam: .fx,
        .dropsL: .fx,
        .dropsR: .fx,
        .patLines: .fx,
        .bigNote: .fx,
        .noteHit: .fx,
        .cheerSplash: .fx,
        .cheerCrack: .fx,
        .cheerNotes: .fx,
        .cheerWind: .fx,
    ]

    static let kuro: [KuroPart: Spot] = [
        .hairBack: .figure,
        .earL: .figure,
        .earR: .figure,
        .faceBase: .figure,
        .hairFringe: .figure,
        .backHead: .figure,
        .catEars: .figure,
        .tennisHeadband: Spot(.headTop, "tennisHeadband"),
        .itemSakura: Spot(.headTop, "itemSakura"),
        .tennisPonytail: Spot(.ponytail, "马尾"),
        .itemScrunchie: Spot(.ponytail, "马尾"),
        .eyesOpen: Spot(.eyes, "眼睛"),
        .eyesClosed: Spot(.eyes, "眼睛"),
        .eyesDrowsy: Spot(.eyes, "眼睛"),
        .eyesBright: Spot(.eyes, "眼睛"),
        .eyesDown: Spot(.eyes, "眼睛"),
        .eyesHappy: Spot(.eyes, "眼睛"),
        .eyesSurprised: Spot(.eyes, "眼睛"),
        .eyesLow: Spot(.eyes, "眼睛"),
        .deskGlasses: Spot(.eyes, "deskGlasses"),
        .maskWork: Spot(.maskFace, "maskWork"),
        .mouthCat: Spot(.mouth, "嘴"),
        .mouthFlat: Spot(.mouth, "嘴"),
        .mouthSmile: Spot(.mouth, "嘴"),
        .mouthO: Spot(.mouth, "嘴"),
        .blush: Spot(.cheek, "blush"),
        .tapRub: Spot(.cheek, "tapRub"),
        .jacketWork: Spot(.torso, "外套"),
        .jacketChill: Spot(.torso, "外套"),
        .jacketTennis: Spot(.torso, "外套"),
        .jacketDesk: Spot(.torso, "外套"),
        .workBadge: Spot(.badge, "workBadge"),
        .itemBlanket: Spot(.lap, "itemBlanket"),
        .tennisRacket: Spot(.handR, "tennisRacket"),
        .itemGoldRacket: Spot(.handR, "itemGoldRacket"),
        .chillCup: Spot(.handR, "chillCup"),
        .workStylus: Spot(.handR, "workStylus"),
        .deskPen: Spot(.handR, "deskPen"),
        .deskBooks: Spot(.handR, "deskBooks"),
        .tapBall: Spot(.handR, "tapBall"),
        .itemSpin: Spot(.handR, "itemSpin"),
        .workTablet: Spot(.handsFront, "workTablet"),
        .tapTablet: Spot(.handsFront, "tapTablet"),
        .tapCup: Spot(.handsFront, "tapCup"),
        .overtimeHand: Spot(.handsFront, "overtimeHand"),
        .tapFinger: Spot(.handsFront, "tapFinger"),
        .tapRubSleeveWork: Spot(.handsFront, "揉眼袖子"),
        .tapRubSleeveChill: Spot(.handsFront, "揉眼袖子"),
        .tapRubSleeveTennis: Spot(.handsFront, "揉眼袖子"),
        .tapRubSleeveDesk: Spot(.handsFront, "揉眼袖子"),
        .itemFlower: Spot(.corner1, "itemFlower"),
        .itemLamp: Spot(.corner1, "itemLamp"),
        .itemBag: Spot(.corner1, "itemBag"),
        .overtimeDesk: Spot(.scene, "overtimeDesk"),
        .overtimeSign: .fx,
        .tapPuff: .fx,
        .tapSparkle: .fx,
        .tapGlint: .fx,
        .tapDots: .fx,
        .tapHeart: .fx,
    ]

    // §9.3 (10/13 夜 included): the jacket carries one of chain, towel or apron; bath blush beside the bandage;
    // the swimming cheer's ear tap over the earring.
    /// Things that may share a place on purpose.
    static let allowed: [Place: [Set<String>]] = [
        .eyes: [["眼睛", "deskGlasses"]],
        .neck: [["面罩", "帽兜"]],
        .deskR: [["deskMonitor", "罐子堆"]],
        .cheek: [["bandage", "bathBlush"]],
        .earL: [["耳机", "earringNeon"], ["cheerEarTap", "earringNeon"]],
        .torso: [["外套", "金链"], ["外套", "towel"], ["外套", "apron"]],
    ]

    /// Parts that fill the room corner while they show (`RunnerFigure.cornerTakers`).
    static let cornerTakers: [RunnerPart] = [.door, .gymBag, .shopBag, .toteBag, .paperBagL, .blanket]

    // §4 step 5 and §9.4, plus the bath and the head scratch by the monitor (§5-5). Pairs in one place need no
    // entry: the place check finds them.
    /// Pairs of HAKU's parts that never show together.
    static let hakuForbidden: [(RunnerPart, RunnerPart)] =
        [
            (.maskUp, .bandage), (.pillow, .roomPc), (.cupL, .roomPc), (.gloveL, .peaceHand), (.gloveR, .peaceHand),
            (.bandage, .mic), (.peaceHand, .mic), (.rubHand, .roomPc), (.bathBubbles, .roomPc), (.scratchHand, .roomPc),
        ]
        + cornerTakers.flatMap { taker in
            [RunnerPart.roomPlant, .roomBag, .heavyBag, .runningShoes].map { (taker, $0) }
        }

    // §9.4: her blanket on the lap never comes with a book or a hot drink in hand.
    /// Pairs of KURO's parts that never show together.
    static let kuroForbidden: [(KuroPart, KuroPart)] = [KuroPart.chillCup, .tapCup, .deskBooks].map {
        (.itemBlanket, $0)
    }

    static let glovesProp = "新（工程二组 2026-10-13）：拳击模式戴着拳套时，手里的道具不让位，一只手两样东西"
    static let headgear = "新（工程二组 2026-10-13）：庆祝或洗澡的头上物件和头带、耳机同在头顶"
    static let tapWithProp = "新（工程二组 2026-10-13）：右手拿着东西时又点手表，一只手两样东西"
    static let new9 = "新（工程二组 2026-10-13，按 §9 分组）：同一只手或同一位置两样，UI 一组定改还是列进 §9.3"

    // Found by this test on main 0275084 with the §9 table; §5 numbers are the placement map's.
    /// HAKU's conflicts that exist today, with where they were reported.
    static let hakuKnown: [String: String] = [
        "bandage+mic": "§5-2 面罩放下、耳机还在时创可贴和麦克风重叠",
        "bath_bubbles+room_pc": "§5-5 洗澡不藏房间显示器",
        "earL: cheerEarTap+耳机": "新（工程二组 2026-10-13）：游泳庆祝点耳朵，压在左耳罩上",
        "earR: peaceHand+耳机": "§5-4 剪刀手和右耳罩",
        "handL: cheekHand+拳套": glovesProp,
        "handL: rubHand+拳套": glovesProp,
        "handL: shampoo+拳套": glovesProp,
        "handL: 拳套+擦汗毛巾": glovesProp,
        "handR: backFist+monsterCan": "新（工程二组 2026-10-13）：捶肩、握拳时右手还拿着罐子",
        "handR: backFist+拳套": glovesProp,
        "handR: camera+拳套": glovesProp,
        "handR: cheerRacket+拳套": glovesProp,
        "handR: cloth+拳套": glovesProp,
        "handR: coffeeCup+拳套": glovesProp,
        "handR: onigiri+拳套": glovesProp,
        "handR: pencil+拳套": glovesProp,
        "handR: runShoe+拳套": glovesProp,
        "handR: shopBag+拳套": glovesProp,
        "handR: shopBag+拳套+点按手": glovesProp,
        "handR: shopBag+点按手": tapWithProp,
        "handR: spatula+拳套": glovesProp,
        "handR: stickyNote+拳套": glovesProp,
        "handR: stickyNote+拳套+点按手": glovesProp,
        "handR: stickyNote+点按手": tapWithProp,
        "handR: waveHand+拳套": glovesProp,
        "handR: 拳套+推子": glovesProp,
        "handR: 拳套+点按手": glovesProp,
        "handR: 拳套+球": glovesProp,
        "handR: 拳套+碗": glovesProp,
        "headTop: bathTowel+headband": headgear,
        "headTop: cheerGoggles+headband": headgear,
        "headTop: cheerGoggles+耳机": headgear,
        "headTop: cheerHelmet+headband": headgear,
        "headTop: cheerHelmet+耳机": headgear,
        "headTop: headband+耳机": "§5-3 拳击热身和耳机同在头顶",
        "peace_hand+mic": "§5-9 剪刀手碰到麦克风",
        "rub_hand+room_pc": "§5-8 揉眼的手碰到左边显示器",
        "scratch_hand+room_pc": "§5-5 挠头的手碰到房间显示器",
        "torso: apron+外套+金链": "新（工程二组 2026-10-13）：副业的金链和做饭的围裙同在胸前",
        "torso: towel+外套+金链": "新（工程二组 2026-10-13）：副业的金链和健身回来的毛巾同在胸前",
    ]

    // Found under the §9 groups on main c302979; UI 一组 decides whether each is a fix or a §9.3 allowed entry.
    /// KURO's conflicts that exist today, with where they were reported.
    static let kuroKnown: [String: String] = [
        "cheek: blush+tapRub": new9,
        "handR: chillCup+itemSpin": new9,
        "handR: deskBooks+deskPen": new9,
        "handR: itemGoldRacket+tapBall": new9,
        "handR: tapBall+tennisRacket": new9,
        "handsFront: workTablet+揉眼袖子": new9,
        "item_blanket+chill_cup": new9,
    ]

    /// The conflicts among `parts`: a place holding two things, as "place: a+b", and a forbidden pair, as "a+b".
    static func conflicts<Part: RawRepresentable & Hashable>(
        in parts: [Part],
        spots: [Part: Spot],
        forbidden: [(Part, Part)] = []
    ) -> [String] where Part.RawValue == String {
        var things: [Place: Set<String>] = [:]
        for part in parts {
            guard let spot = spots[part], spot.isChecked else { continue }
            things[spot.place, default: []].insert(spot.thing)
        }
        let crowded = things.filter { place, held in
            held.count > 1 && !(allowed[place] ?? []).contains { held.isSubset(of: $0) }
        }
        var found = crowded.map {
            "\($0.key.rawValue): \($0.value.sorted().joined(separator: "+"))"
        }
        let shown = Set(parts)
        for (a, b) in forbidden where shown.contains(a) && shown.contains(b) {
            found.append("\(a.rawValue)+\(b.rawValue)")
        }
        return found
    }
}

@Suite struct PlacementTests {
    @Test func everyHakuPartHasASpot() {
        let missing = RunnerPart.allCases.filter { Placement.haku[$0] == nil }.map(\.rawValue)
        #expect(missing.isEmpty, "Add these to Placement.haku and the placement map first: \(missing)")
    }

    @Test func everyKuroPartHasASpot() {
        let missing = KuroPart.allCases.filter { Placement.kuro[$0] == nil }.map(\.rawValue)
        #expect(missing.isEmpty, "Add these to Placement.kuro and the placement map first: \(missing)")
    }

    @Test func hakuKeepsOneThingPerPlace() {
        var found: [String: String] = [:]
        for state in PlacementPoses.haku {
            let parts = RunnerFigure.parts(for: state.mode, pose: state.pose)
            for conflict in Placement.conflicts(in: parts, spots: Placement.haku, forbidden: Placement.hakuForbidden) {
                found[conflict] = found[conflict] ?? state.label
            }
        }
        check(found, known: Placement.hakuKnown)
    }

    @Test func kuroKeepsOneThingPerPlace() {
        var found: [String: String] = [:]
        for state in PlacementPoses.kuro {
            let parts = KuroFigure.parts(for: state.look, pose: state.pose)
            for conflict in Placement.conflicts(in: parts, spots: Placement.kuro, forbidden: Placement.kuroForbidden) {
                found[conflict] = found[conflict] ?? state.label
            }
        }
        check(found, known: Placement.kuroKnown)
    }

    /// Fails on a conflict not in `known`, and on a known conflict that no longer happens.
    func check(_ found: [String: String], known: [String: String]) {
        let new = found.filter { known[$0.key] == nil }.map { "\($0.key) (\($0.value))" }.sorted()
        #expect(
            new.isEmpty, "Two things in one place. Fix it, or list it in Placement with the map's §5 number: \(new)")
        for (conflict, reason) in known.sorted(by: { $0.key < $1.key }) {
            withKnownIssue(Comment(rawValue: "\(conflict): \(reason)")) {
                #expect(found[conflict] == nil, "\(conflict) in \(found[conflict] ?? "")")
            }
        }
    }
}
