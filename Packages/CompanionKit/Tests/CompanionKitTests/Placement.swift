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
    /// A place on the body or in the room, from the placement map §1 and §2.
    enum Place: String, Sendable {
        /// Face, hair, ears, eyes, mouth and jacket: part of the character, not checked.
        case figure
        /// Short effects that float over everything: not checked.
        case fx
        case headTop, eyes, maskFace, faceLow, cheek, mic, earL, earR, neck, torso, lap, ponytail
        case handR, handL, handsFront
        case window, door, earSideL, leftWall, pillow, corner, shoes, deskR, bottom
    }

    /// Where a part sits and the thing it belongs to.
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

    // The room corner is split as in §7: the room item on the left, the running shoes beside it.
    static let haku: [RunnerPart: Spot] = [
        .cheerMountains: .fx,
        .door: Spot(.door, "door"),
        .sunlight: Spot(.window, "sunlight"),
        .roomPc: Spot(.earSideL, "roomPc"),
        .deskMonitor: Spot(.deskR, "deskMonitor"),
        .pillow: Spot(.pillow, "pillow"),
        .roomPlant: Spot(.corner, "roomItem"),
        .roomBag: Spot(.corner, "roomItem"),
        .runningShoes: Spot(.shoes, "runningShoes"),
        .heavyBag: Spot(.leftWall, "heavyBag"),
        .speedLines: .fx,
        .sunIcon: .fx,
        .walkDust: .fx,
        .shopShine: .fx,
        .jacket: .figure,
        .stripeNeon: .figure,
        .hoodCollar: .figure,
        .hoodieStrings: .figure,
        .towel: Spot(.torso, "towel"),
        .blanket: Spot(.bottom, "sofa"),
        .hairBack: .figure,
        .earL: .figure,
        .earR: .figure,
        .faceBase: .figure,
        .headBack: .figure,
        .eyesWork: .figure,
        .lidsWork: .figure,
        .eyebags: .figure,
        .browsWork: .figure,
        .eyesChill: .figure,
        .cateyeL: .figure,
        .cateyeR: .figure,
        .browsBox: .figure,
        .eyesMoney: .figure,
        .eyeGlint: .figure,
        .eyesSleepy: .figure,
        .eyesClosed: .figure,
        .mouthSmile: .figure,
        .mouthFang: .figure,
        .mouthYawn: .figure,
        .maskUp: Spot(.maskFace, "maskUp"),
        .panelLines: Spot(.maskFace, "maskUp"),
        .ledLine: Spot(.maskFace, "maskUp"),
        .ledYen: Spot(.maskFace, "maskUp"),
        .ledCode: Spot(.maskFace, "maskUp"),
        .maskStripes: Spot(.maskFace, "maskUp"),
        .maskDown: Spot(.neck, "maskDown"),
        .bandage: Spot(.cheek, "bandage"),
        .maskStripesDown: Spot(.neck, "maskDown"),
        .hairFringe: .figure,
        .hairTuft: .figure,
        .scratchHand: Spot(.handL, "scratch"),
        .rubHand: Spot(.handL, "rubEye"),
        .earringNeon: .figure,
        .headband: Spot(.headTop, "headband"),
        .headset: Spot(.headTop, "headset"),
        .cupL: Spot(.earL, "headset"),
        .cupR: Spot(.earR, "headset"),
        .mic: Spot(.mic, "headset"),
        .gloveL: Spot(.handL, "gloves"),
        .gloveTapeLeft: Spot(.handL, "gloves"),
        .gloveR: Spot(.handR, "gloves"),
        .gloveTapeRight: Spot(.handR, "gloves"),
        .monsterCan: Spot(.handR, "can"),
        .runShoe: Spot(.handR, "runShoe"),
        .chainGold: Spot(.torso, "chain"),
        .coin: .fx,
        .desk: Spot(.bottom, "desk"),
        .canStackOne: Spot(.corner, "canStack"),
        .canStackTwo: Spot(.corner, "canStack"),
        .canStackThree: Spot(.corner, "canStack"),
        .laptop: Spot(.handsFront, "laptop"),
        .laptopClosed: Spot(.handsFront, "laptop"),
        .typingHands: Spot(.handsFront, "laptop"),
        .soul: .fx,
        .codeBits: .fx,
        .sofaArm: Spot(.bottom, "sofa"),
        .toothbrush: Spot(.handR, "toothbrush"),
        .watchWrist: Spot(.handR, "watchTap"),
        .tapHand: Spot(.handR, "watchTap"),
        .backFist: Spot(.handR, "fist"),
        .thumpLines: .fx,
        .phone: Spot(.handsFront, "phone"),
        .phoneFeed: Spot(.handsFront, "phone"),
        .phoneBack: Spot(.handsFront, "phone"),
        .phoneHand: Spot(.handsFront, "phone"),
        .handheld: Spot(.handsFront, "handheld"),
        .onigiri: Spot(.handR, "onigiri"),
        .sketchbook: Spot(.handsFront, "drawing"),
        .pencil: Spot(.handR, "drawing"),
        .cloth: Spot(.handR, "cloth"),
        .gymBag: Spot(.corner, "gymBag"),
        .handWeight: Spot(.handR, "handWeight"),
        .peaceHand: Spot(.earR, "peace"),
        .dumbbell: Spot(.handsFront, "dumbbell"),
        .sparkle: .fx,
        .eyeSwirlL: .figure,
        .eyeSwirlR: .figure,
        .dizzyStar: .fx,
        .musicNote: .fx,
        .zzz: .fx,
        .coffeeSteam: .fx,
        .blowLines: .fx,
        .coffeeCup: Spot(.handR, "coffee"),
        .riceBowl: Spot(.handsFront, "meal"),
        .chopsticks: Spot(.handR, "meal"),
        .macbook: Spot(.handsFront, "macbook"),
        .typeHandL: Spot(.handsFront, "macbook"),
        .typeHandR: Spot(.handsFront, "macbook"),
        .screenGlow: .fx,
        .phoneEar: Spot(.earR, "phoneCall"),
        .talkDots: .fx,
        .toteBag: Spot(.corner, "toteBag"),
        .paperBagL: Spot(.corner, "paperBags"),
        .paperBagR: Spot(.handR, "paperBags"),
        .apron: Spot(.torso, "apron"),
        .spatula: Spot(.handR, "spatula"),
        .cameraFlash: .fx,
        .camera: Spot(.handsFront, "camera"),
        .waveArcs: .fx,
        .waveHand: Spot(.handR, "wave"),
        .hairBits: .fx,
        .clipArm: Spot(.handR, "haircut"),
        .clipper: Spot(.handR, "haircut"),
        .buzzLines: .fx,
        .cheekHand: Spot(.handL, "cheekHand"),
        .ouchLines: .fx,
        .bathBubbles: .fx,
        .bathTowel: Spot(.headTop, "bathTowel"),
        .headSteam: .fx,
        .bathBlush: .figure,
        .shampoo: Spot(.handL, "shampoo"),
        .rubberDuck: Spot(.bottom, "duck"),
        .dropsL: .fx,
        .dropsR: .fx,
        .rubTowelL: Spot(.headTop, "bathTowel"),
        .rubTowelR: Spot(.headTop, "bathTowel"),
        .stickyNote: Spot(.handR, "stickyNote"),
        .shopBag: Spot(.corner, "shopBag"),
        .crateCans: Spot(.handsFront, "crate"),
        .crateBox: Spot(.handsFront, "crate"),
        .crateFlapL: Spot(.handsFront, "crate"),
        .crateFlapR: Spot(.handsFront, "crate"),
        .patLines: .fx,
        .bigNote: .fx,
        .noteHit: .fx,
        .cheerLegLines: .fx,
        .cheerHelmet: Spot(.headTop, "helmet"),
        .cheerSplash: .fx,
        .cheerGoggles: Spot(.headTop, "goggles"),
        .cheerEarTap: Spot(.earL, "earTap"),
        .cheerKick: .fx,
        .cheerRacket: Spot(.handR, "racket"),
        .cheerBallHand: Spot(.handR, "ball"),
        .cheerBall: Spot(.handR, "ball"),
        .cheerStretchArms: .fx,
        .cheerCrack: .fx,
        .cheerNotes: .fx,
        .cheerWind: .fx,
    ]

    static let kuro: [KuroPart: Spot] = [
        .itemFlower: Spot(.corner, "flower"),
        .itemLamp: Spot(.corner, "lamp"),
        .tennisPonytail: .figure,
        .hairBack: .figure,
        .itemScrunchie: Spot(.ponytail, "scrunchie"),
        .jacketWork: .figure,
        .jacketChill: .figure,
        .itemBlanket: Spot(.lap, "blanket"),
        .jacketTennis: .figure,
        .itemBag: Spot(.corner, "bag"),
        .jacketDesk: .figure,
        .workTablet: Spot(.handsFront, "tablet"),
        .workStylus: Spot(.handR, "stylus"),
        .chillCup: Spot(.handR, "cup"),
        .earL: .figure,
        .earR: .figure,
        .faceBase: .figure,
        .blush: .figure,
        .eyesOpen: .figure,
        .eyesClosed: .figure,
        .eyesDrowsy: .figure,
        .eyesBright: .figure,
        .eyesDown: .figure,
        .eyesHappy: .figure,
        .eyesSurprised: .figure,
        .eyesLow: .figure,
        .mouthCat: .figure,
        .mouthFlat: .figure,
        .mouthSmile: .figure,
        .mouthO: .figure,
        .maskWork: Spot(.faceLow, "mask"),
        .hairFringe: .figure,
        .backHead: .figure,
        .tennisHeadband: Spot(.headTop, "headband"),
        .itemSakura: Spot(.headTop, "headband"),
        .catEars: .figure,
        .workBadge: Spot(.torso, "badge"),
        .deskGlasses: Spot(.eyes, "glasses"),
        .deskBooks: Spot(.handR, "deskSet"),
        .deskPen: Spot(.handR, "deskSet"),
        .tennisRacket: Spot(.handR, "racket"),
        .itemGoldRacket: Spot(.handR, "racket"),
        .overtimeDesk: Spot(.bottom, "overtimeDesk"),
        .overtimeHand: Spot(.handsFront, "chinHand"),
        .overtimeSign: .fx,
        .itemSpin: .fx,
        .tapTablet: Spot(.handsFront, "tablet"),
        .tapCup: Spot(.handsFront, "cup"),
        .tapPuff: .fx,
        .tapBall: .fx,
        .tapSparkle: .fx,
        .tapFinger: Spot(.eyes, "glasses"),
        .tapGlint: .fx,
        .tapRubSleeveWork: Spot(.handL, "rub"),
        .tapRubSleeveChill: Spot(.handL, "rub"),
        .tapRubSleeveTennis: Spot(.handL, "rub"),
        .tapRubSleeveDesk: Spot(.handL, "rub"),
        .tapRub: Spot(.handL, "rub"),
        .tapDots: .fx,
        .tapHeart: .fx,
    ]

    /// Parts that fill the room corner while they show (`RunnerFigure.cornerTakers`).
    static let cornerTakers: [RunnerPart] = [.door, .gymBag, .shopBag, .toteBag, .paperBagL, .blanket]

    // §4 step 5, plus the bath and the head scratch by the monitor (§5-5). Intended overlaps (the sunlight over
    // HAKU, the cans in front of the desk monitor, §4 step 6) are in places of their own, so need no entry.
    /// Pairs of HAKU's parts that never show together.
    static let hakuForbidden: [(RunnerPart, RunnerPart)] =
        [
            (.maskUp, .bandage), (.pillow, .roomPc), (.cupL, .roomPc), (.gloveL, .peaceHand), (.gloveR, .peaceHand),
            (.headband, .headset), (.peaceHand, .cupR), (.bandage, .mic), (.peaceHand, .mic), (.rubHand, .roomPc),
            (.bathBubbles, .roomPc), (.scratchHand, .roomPc),
        ]
        + cornerTakers.flatMap { taker in [RunnerPart.roomPlant, .roomBag, .runningShoes].map { (taker, $0) } }

    static let glovesProp = "新（工程二组 2026-10-13）：拳击模式戴着拳套时，手里的道具不让位，一只手两样东西"
    static let headgear = "新（工程二组 2026-10-13）：庆祝或洗澡的头上物件和头带、耳机同在头顶"

    // Found by this test on main b9338da; §5 numbers are the placement map's. UI fixes them in batch 1.
    /// HAKU's conflicts that exist today, with where they were reported.
    static let hakuKnown: [String: String] = [
        "headTop: headband+headset": "§5-3 拳击热身和耳机同在头顶",
        "headband+headset": "§5-3 拳击热身和耳机同在头顶",
        "earR: headset+peace": "§5-4 剪刀手和右耳罩",
        "peace_hand+cup_R": "§5-4 剪刀手和右耳罩",
        "peace_hand+mic": "§5-9 剪刀手碰到麦克风",
        "bandage+mic": "§5-2 面罩放下、耳机还在时创可贴和麦克风重叠",
        "rub_hand+room_pc": "§5-8 揉眼的手碰到左边显示器",
        "bath_bubbles+room_pc": "§5-5 洗澡不藏房间显示器",
        "scratch_hand+room_pc": "§5-5 挠头的手碰到房间显示器",
        "handR: can+fist": "新（工程二组 2026-10-13）：捶肩、握拳时右手还拿着罐子",
        "handR: stickyNote+watchTap": "新（工程二组 2026-10-13）：举便利贴时又点手表，右手两样东西",
        "handR: gloves+stickyNote+watchTap": glovesProp,
        "handR: gloves+watchTap": glovesProp,
        "handR: gloves+stickyNote": glovesProp,
        "handR: fist+gloves": glovesProp,
        "handR: gloves+runShoe": glovesProp,
        "handR: drawing+gloves": glovesProp,
        "handR: gloves+onigiri": glovesProp,
        "handR: cloth+gloves": glovesProp,
        "handR: coffee+gloves": glovesProp,
        "handR: gloves+spatula": glovesProp,
        "handR: gloves+wave": glovesProp,
        "handR: gloves+haircut": glovesProp,
        "handR: gloves+meal": glovesProp,
        "handR: gloves+paperBags": glovesProp,
        "handR: ball+gloves": glovesProp,
        "handR: gloves+racket": glovesProp,
        "handL: gloves+shampoo": glovesProp,
        "handL: gloves+rubEye": glovesProp,
        "handL: cheekHand+gloves": glovesProp,
        "headTop: bathTowel+headband": headgear,
        "headTop: headband+helmet": headgear,
        "headTop: goggles+headband": headgear,
        "headTop: headset+helmet": headgear,
        "headTop: goggles+headset": headgear,
        "earL: earTap+headset": headgear,
        "torso: chain+towel": "新（工程二组 2026-10-13）：副业的金链和健身回来的毛巾同在胸前",
        "torso: apron+chain": "新（工程二组 2026-10-13）：副业的金链和做饭的围裙同在胸前",
    ]

    /// KURO's conflicts that exist today, with where they were reported.
    static let kuroKnown: [String: String] = [:]

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
        var found = things.filter { $0.value.count > 1 }.map {
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
            for conflict in Placement.conflicts(in: parts, spots: Placement.kuro) {
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
