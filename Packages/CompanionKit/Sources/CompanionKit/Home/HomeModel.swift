import Foundation
import HubCore
import Observation
import SwiftUI

// Issue #485: everything here is mock data for the prototype. Nothing reads or writes the real
// mode log, can ledger or wardrobe.

/// A top HAKU can wear at home.
enum HomeOutfit: String, CaseIterable, Sendable {
    case jacket, blazer, aloha, flame, varsity

    var name: String {
        switch self {
        case .jacket: "默认外套"
        case .blazer: "学院西装"
        case .aloha: "浪花夏威夷衫"
        case .flame: "火焰连帽卫衣"
        case .varsity: "校队夹克"
        }
    }

    /// The price in cans, or `nil` when owned from the start.
    var price: Int? {
        switch self {
        case .jacket, .blazer, .aloha: nil
        case .flame: 40
        case .varsity: 80
        }
    }

    /// The drawn parts of the top, in place of the jacket.
    var parts: [RunnerPart] {
        switch self {
        case .jacket: [.jacket, .stripeNeon, .hoodCollar]
        case .blazer: [.topWorkIvy]
        case .aloha: [.topChillAloha]
        case .flame: [.topChillFlame, .hoodieStringsCyan]
        case .varsity: [.setVarsityTop]
        }
    }

    /// The colour of the sleeves and of the top seen from behind.
    var base: Color {
        switch self {
        case .jacket: RunnerPalette.jacketChill
        case .blazer: RunnerPalette.hood
        case .aloha: RunnerPalette.catOrange
        case .flame: RunnerPalette.bubblegum
        case .varsity: RunnerPalette.varsityRed
        }
    }
}

/// A piece of furniture whose colour can be changed.
enum HomePaintable: String, CaseIterable, Sendable {
    case sofa, bed, rug, walls

    var name: String {
        switch self {
        case .sofa: "沙发"
        case .bed: "被子"
        case .rug: "地毯"
        case .walls: "墙"
        }
    }

    /// The colours to pick from; the first is the default.
    var swatches: [UInt32] {
        switch self {
        case .sofa: [0x2D3250, 0x3A6B58, 0xFF8FC8, 0xFF9F43]
        case .bed: [0x3A6B58, 0x2D3250, 0xC7A6FF, 0xFF3B4E]
        case .rug: [0xAFC6E3, 0xEADCC2, 0x7CFF4F, 0xFFE14D]
        case .walls: [0xF6E4C8, 0xDDEBD9, 0xE3E0F5, 0xF7D9D9]
        }
    }
}

/// A keepsake on the reward shelf, earned by something that really happened.
struct HomeKeepsake: Identifiable, Sendable {
    let id: String
    let name: String
    let earned: String
    let date: String
}

/// A shop entry for the home.
enum HomeProduct: Hashable, Sendable {
    case item(HomeItem)
    case outfit(HomeOutfit)

    static let all: [HomeProduct] = [
        .item(.plant), .item(.bag), .item(.cactus), .item(.speaker), .outfit(.flame), .outfit(.varsity),
    ]

    /// What the shop offers with `card` as the identity card: the bag is a boxing card item.
    static func offered(card: IdentityKind) -> [HomeProduct] {
        all.filter { $0 != .item(.bag) || card == .boxing }
    }

    var name: String {
        switch self {
        case .item(.plant): "房间绿植"
        case .item(.bag): "小沙袋"
        case .item(.cactus): "小仙人掌"
        case .item(.speaker): "迷你音箱"
        case .outfit(let o): o.name
        }
    }

    var price: Int {
        switch self {
        case .item(.plant): 8
        case .item(.bag): 15
        case .item(.cactus): 15
        case .item(.speaker): 20
        case .outfit(let o): o.price ?? 0
        }
    }

    /// Where the bought thing shows up.
    var place: String {
        switch self {
        case .item(.plant): "门口角落"
        case .item(.bag): "窗边，拳击日打它"
        case .item(.cactus): "书桌上"
        case .item(.speaker): "沙发旁边，下班时放歌"
        case .outfit: "衣柜里，随时能换"
        }
    }
}

/// A line in the TODAY list.
struct HomeTimelineEntry: Identifiable, Sendable {
    let id = UUID()
    let time: String
    let mode: Mode?
    let title: String
}

/// Something the scene plays once.
enum HomeCue: Equatable, Sendable {
    case bounce
    case annoyed
    case changed
    case placed(HomeItem)
    case poof
}

/// State of the home prototype: where HAKU is going, what he wears, what the room holds.
@MainActor
@Observable
final class HomeModel {
    private(set) var mode: Mode = .chill
    /// The user's identity card, the fourth mode. Only the boxing card is drawn in the prototype.
    let card: IdentityKind
    /// Where HAKU is, or is walking to.
    private(set) var spot: HomeSpot = .idle
    /// Where HAKU was dropped after being carried, until he walks somewhere.
    private(set) var dropPoint: GridPoint?
    private(set) var energy: Double = 62
    private(set) var cans = 46
    private(set) var outfit: HomeOutfit = .jacket
    private(set) var ownedOutfits: Set<HomeOutfit> = [.jacket, .blazer, .aloha]
    private(set) var items: Set<HomeItem> = []
    private(set) var colors: [HomePaintable: Int] = [:]
    var isNight: Bool
    /// What HAKU says on the card.
    private(set) var line = "……来了。随便坐。"
    private(set) var timeline: [HomeTimelineEntry]
    /// Bumped on every change the scene draws.
    private(set) var revision = 0
    /// One-off animations for the scene, oldest first.
    private(set) var cues: [HomeCue] = []

    let keepsakes: [HomeKeepsake] = [
        HomeKeepsake(id: "gloves", name: "第一副拳套", earned: "第一次拳击日打满 30 分钟", date: "9 月 21 日"),
        HomeKeepsake(id: "shoe", name: "旧跑鞋", earned: "第一次跑完 5 公里", date: "9 月 27 日"),
        HomeKeepsake(id: "cans", name: "罐子塔", earned: "攒到第 50 个罐子", date: "10 月 6 日"),
        HomeKeepsake(id: "trophy", name: "小奖杯", earned: "一周有 3 天准点睡觉", date: "10 月 12 日"),
    ]

    private var taps: [Date] = []
    private var lineIndex = 0

    init(night: Bool? = nil, cans: Int = 46, card: IdentityKind = .boxing, now: Date = .now) {
        self.cans = cans
        self.card = card
        let hour = Calendar.current.component(.hour, from: now)
        isNight = night ?? (hour >= 18 || hour < 6)
        timeline = [
            HomeTimelineEntry(time: "07:40", mode: nil, title: "起床，睡了 6 小时 50 分"),
            HomeTimelineEntry(time: "09:05", mode: .work, title: "上班"),
            HomeTimelineEntry(time: "18:40", mode: .chill, title: "下班"),
        ]
    }

    /// The colour picked for `piece`.
    func color(_ piece: HomePaintable) -> UInt32 {
        piece.swatches[colors[piece] ?? 0]
    }

    // MARK: Actions

    /// Switches the mode and sends HAKU to act it out.
    func switchMode(_ new: Mode, at time: String = HomeModel.clock()) {
        mode = new
        timeline.append(HomeTimelineEntry(time: time, mode: new, title: title(new)))
        energy = max(5, min(100, energy + Self.energyCost(new)))
        go(Self.spot(for: new, card: card, hasBag: items.contains(.bag)))
        line = Self.modeLine(new, card: card, hasBag: items.contains(.bag))
    }

    /// Reacts to a tap in the room.
    func tap(_ hotspot: HomeHotspot, at date: Date = .now) {
        switch hotspot {
        case .haku: tapHaku(at: date)
        case .desk:
            go(mode == .money ? .side : .work)
            line = "坐一会儿。不一定干活。"
        case .sofa:
            go(.sofa)
            line = energy < 35 ? "沙发是我的。今天电量不够。" : "沙发是我的。"
        case .bed:
            go(.rest)
            line = "……再五分钟。"
        case .bag:
            go(.box)
            line = "左、右、左。"
        case .window:
            go(.window)
            line = isNight ? "楼下的灯还亮着。" : "今天天气还行。"
        case .wardrobe:
            go(.wardrobe)
            line = "穿什么都一样帅。"
        case .shop:
            go(.shop)
            line = "罐子要花在刀刃上。"
        case .shelf:
            line = "这些都是真的发生过的。"
        case .exit:
            break
        }
        changed()
    }

    /// Spends cans on `product`; returns `false` when there aren't enough or it is already owned.
    @discardableResult
    func buy(_ product: HomeProduct) -> Bool {
        guard !owns(product), cans >= product.price else { return false }
        cans -= product.price
        switch product {
        case .item(let item):
            items.insert(item)
            cues.append(.placed(item))
            line = "……行吧，放这儿挺好。"
        case .outfit(let o):
            ownedOutfits.insert(o)
            line = "放衣柜里了。"
        }
        changed()
        return true
    }

    /// Whether `product` is already bought.
    func owns(_ product: HomeProduct) -> Bool {
        switch product {
        case .item(let item): items.contains(item)
        case .outfit(let o): ownedOutfits.contains(o)
        }
    }

    /// Puts on an owned outfit.
    func wear(_ new: HomeOutfit) {
        guard ownedOutfits.contains(new), new != outfit else { return }
        outfit = new
        cues.append(.poof)
        line = "换好了。别盯着看。"
        changed()
    }

    /// Picks swatch `index` for `piece`.
    func paint(_ piece: HomePaintable, _ index: Int) {
        guard piece.swatches.indices.contains(index) else { return }
        colors[piece] = index
        changed()
    }

    func toggleNight() {
        isNight.toggle()
        line = isNight ? "天黑了。灯开着就行。" : "天亮了。"
        changed()
    }

    /// HAKU was carried and let go over `hotspot`, or over the floor at `point`.
    func drop(on hotspot: HomeHotspot?, at point: GridPoint) {
        switch hotspot {
        case .sofa: go(.sofa)
        case .bed: go(.rest)
        case .desk: go(mode == .money ? .side : .work)
        case .bag: go(.box)
        default:
            let inside = GridPoint(x: min(max(point.x, 2.4), 6.2), y: min(max(point.y, 3.2), 9.4))
            dropPoint = inside
            spot = .idle
            cues.append(.bounce)
        }
        line = "……放我下来就行。"
        changed()
    }

    /// HAKU was picked up.
    func lift() {
        line = "喂。"
        changed()
    }

    /// Advances resting: energy climbs slowly while HAKU lies in bed.
    func tick(_ seconds: Double) {
        guard spot == .rest, energy < 100 else { return }
        let before = Int(energy)
        energy = min(100, energy + seconds * 0.8)
        if Int(energy) / 10 != before / 10 { changed() }
    }

    /// Takes the cues the scene has not played yet.
    func takeCues() -> [HomeCue] {
        defer { cues = [] }
        return cues
    }

    // MARK: Helpers

    private func tapHaku(at date: Date) {
        taps = taps.filter { date.timeIntervalSince($0) < 2 } + [date]
        if taps.count >= 3 {
            taps = []
            line = "够了。"
            cues.append(.annoyed)
            return
        }
        let lines = Self.tapLines(spot: spot, energy: energy)
        line = lines[lineIndex % lines.count]
        lineIndex += 1
        cues.append(.bounce)
    }

    private func go(_ next: HomeSpot) {
        dropPoint = nil
        spot = next
    }

    private func changed() {
        revision += 1
    }

    /// The mode's name; the fourth mode is named after the identity card.
    func title(_ mode: Mode) -> String {
        mode == .boxing ? card.title : mode.title
    }

    // PM 2026-10-15: the fourth mode follows the user's identity card, so its spot and line branch on the card.
    static func spot(for mode: Mode, card: IdentityKind, hasBag: Bool) -> HomeSpot {
        switch mode {
        case .work: .work
        case .chill: .sofa
        case .boxing: cardSpot(card, hasBag: hasBag)
        case .money: .side
        }
    }

    static func cardSpot(_ card: IdentityKind, hasBag: Bool) -> HomeSpot {
        switch card {
        case .boxing: hasBag ? .box : .shadowbox
        default: .idle
        }
    }

    static func modeLine(_ mode: Mode, card: IdentityKind, hasBag: Bool) -> String {
        switch mode {
        case .work: "上班。脑子开机中。"
        case .chill: "下班。今天到此为止。"
        case .boxing:
            switch card {
            case .boxing: hasBag ? "拳击日。沙袋先挨几下。" : "拳击日。没沙袋，打空气也行。"
            default: "\(card.title)。准备出门。"
            }
        case .money: "副业时间。别打扰，也别走。"
        }
    }

    static func energyCost(_ mode: Mode) -> Double {
        switch mode {
        case .work: -8
        case .chill: 4
        case .boxing: -12
        case .money: -5
        }
    }

    static func tapLines(spot: HomeSpot, energy: Double) -> [String] {
        switch spot {
        case .work: ["在忙。", "……这封邮件写第三遍了。"]
        case .side: ["别看，还没做完。", "就差一点。可能。"]
        case .sofa: ["什么也不想做，这也算一种状态。", "遥控器在你那边。"]
        case .rest: ["……再五分钟。", "zzz"]
        case .box, .shadowbox: ["左、右、左。", "沙袋没惹我，是我今天比较硬。"]
        default:
            energy < 35 ? ["电量不太够。", "……干嘛。"] : ["……干嘛。", "看我也不会多一罐。", "嗯。", "今天也没什么特别的。挺好。"]
        }
    }

    static func clock(_ date: Date = .now) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
