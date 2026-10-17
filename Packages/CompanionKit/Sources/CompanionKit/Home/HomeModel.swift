import Foundation
import HubCore
import Observation
import SwiftUI

// Issue #489 (Mike 2026-10-17: the home runs on real data only). The model is built from the app's
// `HomeSnapshot`; changes go back through the page's callbacks and come in again as a new snapshot.

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

    /// The shop item the top is, `nil` for the default jacket.
    var shopID: String? {
        switch self {
        case .jacket: nil
        case .blazer: "haku.top.work.blazer"
        case .aloha: "haku.top.chill.aloha"
        case .flame: "haku.top.chill.flame"
        case .varsity: "haku.set.chill.varsity"
        }
    }

    // The tops drawn in the room so far (M4 adds the rest); anything else worn shows the default jacket.
    /// The room version of what is worn: the first drawn top among `worn` item ids, else the jacket.
    init(worn: Set<String>) {
        self = Self.allCases.first { $0.shopID.map(worn.contains) ?? false } ?? .jacket
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

    /// The piece's id in the saved room layout.
    var layoutID: String { "home.\(rawValue)" }

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
}

extension HomeSnapshot {
    /// HAKU's room before any mode, owning only `owned`; for previews.
    static func preview(owning owned: Set<String> = []) -> HomeSnapshot {
        HomeSnapshot(
            persona: .haku, mode: nil, cards: ModeCards(), cans: 0, owned: owned, wardrobe: Wardrobe(),
            energy: nil, vitals: HakuVitals(), bedtime: .off, today: [],
            room: RoomLayout(persona: .haku, now: .distantPast, deviceID: ""))
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

/// State of the home page: where HAKU is going, what he wears, what the room holds.
@MainActor
@Observable
final class HomeModel {
    /// What the app last sent.
    private(set) var snapshot: HomeSnapshot
    /// The current mode, `nil` before the first one.
    private(set) var mode: Mode?
    /// Where HAKU is, or is walking to.
    private(set) var spot: HomeSpot = .idle
    /// Where HAKU was dropped after being carried, until he walks somewhere.
    private(set) var dropPoint: GridPoint?
    /// Seconds until HAKU leaves a place he was sent to or dropped at and goes back to the mode's spot.
    private(set) var visitLeft: Double?
    /// The room with the colours picked here, saved through the page.
    private(set) var layout: RoomLayout
    /// Whether the room shows every item, owned or not, to see where each one goes. DEBUG builds only.
    private(set) var previewsAllItems = false
    var isNight: Bool
    /// What HAKU says on the card.
    private(set) var line = "……来了。随便坐。"
    /// Bumped on every change the scene draws.
    private(set) var revision = 0
    /// One-off animations for the scene, oldest first.
    private(set) var cues: [HomeCue] = []

    private var taps: [Date] = []
    private var lineIndex = 0

    /// - Parameters:
    ///   - snapshot: what the app shows.
    ///   - night: day or night; by default from the clock.
    ///   - now: the time, for day or night.
    init(snapshot: HomeSnapshot, night: Bool? = nil, now: Date = .now) {
        self.snapshot = snapshot
        mode = snapshot.mode
        layout = snapshot.room
        let hour = Calendar.current.component(.hour, from: now)
        isNight = night ?? (hour >= 18 || hour < 6)
        spot = modeSpot
    }

    /// The user's identity card, the fourth mode.
    var card: IdentityKind? { snapshot.cards.identity }
    var cans: Int { snapshot.cans }
    /// Whether today's energy is low; unknown counts as not low.
    var isLow: Bool { snapshot.energy == .low }
    /// The top HAKU wears in the room.
    var outfit: HomeOutfit { HomeOutfit(worn: snapshot.worn) }
    /// The drawn tops HAKU owns, hanging in the wardrobe; the jacket always.
    var ownedOutfits: [HomeOutfit] {
        HomeOutfit.allCases.filter { $0.shopID.map(snapshot.owned.contains) ?? true }
    }
    /// The items standing in the room: the owned ones, or all of them while previewing.
    var items: Set<HomeItem> {
        previewsAllItems ? Set(HomeItem.allCases) : Set(snapshot.owned.compactMap(HomeItem.init(shopID:)))
    }
    /// The keepsakes on the reward shelf, by name, oldest first.
    var keepsakes: [HomeKeepsake] {
        snapshot.keepsakes.map { HomeKeepsake(id: $0.id, name: ShopItem.item($0.id)?.title ?? $0.id) }
    }
    /// Today's modes, oldest first.
    var timeline: [HomeTimelineEntry] {
        snapshot.today.map {
            HomeTimelineEntry(time: Self.clock($0.startedAt), mode: $0.mode, title: title($0.mode))
        }
    }

    /// The colour picked for `piece`.
    func color(_ piece: HomePaintable) -> UInt32 {
        let picked = piece == .walls ? layout.wallpaper : layout.placements.first { $0.piece == piece.layoutID }?.color
        return picked.flatMap { UInt32($0, radix: 16) }.flatMap { piece.swatches.contains($0) ? $0 : nil }
            ?? piece.swatches[0]
    }

    // MARK: Actions

    /// Takes a new snapshot from the app: HAKU follows a changed mode, and new items show up with a pop.
    func apply(_ new: HomeSnapshot) {
        let before = items
        let modeChanged = new.mode != snapshot.mode
        snapshot = new
        layout = new.room
        for item in items.subtracting(before) { cues.append(.placed(item)) }
        if modeChanged, new.mode != mode {
            mode = new.mode
            go(modeSpot)
            if let mode = new.mode { line = Self.modeLine(mode, title: title(mode), card: card, items: items) }
        }
        changed()
    }

    /// Switches the mode here at once and sends HAKU to act it out; the page also tells the app.
    func switchMode(_ new: Mode) {
        mode = new
        go(modeSpot)
        line = Self.modeLine(new, title: title(new), card: card, items: items)
        changed()
    }

    /// Reacts to a tap in the room.
    func tap(_ hotspot: HomeHotspot, at date: Date = .now) {
        switch hotspot {
        case .haku: tapHaku(at: date)
        case .desk:
            visit(mode == .money ? .side : .work)
            line = "坐一会儿。不一定干活。"
        case .sofa:
            visit(.sofa)
            line = isLow ? "沙发是我的。今天电量不够。" : "沙发是我的。"
        case .bed:
            visit(.rest)
            line = "……再五分钟。"
        case .bag:
            visit(.box)
            line = "左、右、左。"
        case .bench:
            visit(.bench)
            line = "推几下。不数。"
        case .window:
            visit(.window)
            line = isNight ? "楼下的灯还亮着。" : "窗外挺亮。"
        case .wardrobe:
            visit(.wardrobe)
            line = "穿什么都一样帅。"
        case .shop:
            visit(.shop)
            line = "罐子要花在刀刃上。"
        case .shelf:
            line = "这些都是真的发生过的。"
        case .exit:
            break
        }
        changed()
    }

    /// Picks swatch `index` for `piece` and returns the room to save.
    @discardableResult
    func paint(_ piece: HomePaintable, _ index: Int, now: Date = .now, deviceID: String = "") -> RoomLayout {
        guard piece.swatches.indices.contains(index) else { return layout }
        let hex = String(format: "%06X", piece.swatches[index])
        if piece == .walls {
            layout.wallpaper = hex
        } else if let i = layout.placements.firstIndex(where: { $0.piece == piece.layoutID }) {
            layout.placements[i].color = hex
        } else {
            layout.placements.append(RoomPlacement(piece: piece.layoutID, color: hex))
        }
        layout.touch(now: now, deviceID: deviceID)
        changed()
        return layout
    }

    /// Shows or hides every item, owned or not.
    func togglePreviewItems() {
        previewsAllItems.toggle()
        changed()
    }

    /// Switches day and night by hand. DEBUG builds only.
    func toggleNight() {
        isNight.toggle()
        line = isNight ? "天黑了。灯开着就行。" : "天亮了。"
        changed()
    }

    /// HAKU was carried and let go over `hotspot`, or over the floor at `point`.
    func drop(on hotspot: HomeHotspot?, at point: GridPoint) {
        switch hotspot {
        case .sofa: visit(.sofa)
        case .bed: visit(.rest)
        case .desk: visit(mode == .money ? .side : .work)
        case .bag: visit(.box)
        case .bench: visit(.bench)
        default:
            // Dropped on something HAKU can't stand on: he lands on the nearest open floor.
            dropPoint = HomeNav.room(items: items).nearestOpen(to: point)
            spot = .idle
            visitLeft = Self.landingPause
            cues.append(.bounce)
        }
        line = "……放我下来就行。"
        changed()
    }

    /// Puts HAKU on the open floor next to `item`, where he stays.
    func standBeside(_ item: HomeItem) {
        go(.idle)
        dropPoint = Self.previewSpot(item, items: items.union([item]))
        changed()
    }

    /// The open floor next to `item`, a step towards the middle of the room.
    static func previewSpot(_ item: HomeItem, items: Set<HomeItem>? = nil) -> GridPoint {
        // In front of the cactus or the bench HAKU would hide it; by the chair, or left of the bench, he stands
        // beside it.
        let s: GridPoint
        switch item {
        case .cactus: s = GridPoint(x: 1.2, y: 1.6)
        case .bench: s = GridPoint(x: 2.5, y: 3.2)
        default: s = item.spot
        }
        let hub = HomeSpot.hub
        let d = max(0.01, s.distance(to: hub))
        let toward = GridPoint(x: s.x + (hub.x - s.x) / d * 1.3, y: s.y + (hub.y - s.y) / d * 1.3)
        return HomeNav.room(items: items ?? [item]).nearestOpen(to: toward)
    }

    /// HAKU was picked up.
    func lift() {
        line = "喂。"
        changed()
    }

    /// Counts down a visit; when it ends HAKU goes back to the mode's spot.
    func tick(_ seconds: Double) {
        guard let left = visitLeft else { return }
        if left > seconds {
            visitLeft = left - seconds
        } else {
            go(modeSpot)
            changed()
        }
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
        let lines = Self.tapLines(spot: spot, low: isLow)
        line = lines[lineIndex % lines.count]
        lineIndex += 1
        cues.append(.bounce)
    }

    // PM 家 功能范围 v0: tapping furniture or dropping HAKU somewhere is a short visit, not a mode change.
    private func visit(_ next: HomeSpot) {
        go(next)
        if next != modeSpot { visitLeft = Self.visitLength }
    }

    private func go(_ next: HomeSpot) {
        dropPoint = nil
        visitLeft = nil
        spot = next
    }

    /// Where the current mode puts HAKU.
    var modeSpot: HomeSpot {
        mode.map { Self.spot(for: $0, card: card, items: items) } ?? .idle
    }

    /// How long a visit lasts, in seconds.
    static let visitLength = 30.0
    /// How long HAKU stands where he was dropped before walking back.
    static let landingPause = 1.5

    private func changed() {
        revision += 1
    }

    /// The mode's card name, as the user named it.
    func title(_ mode: Mode) -> String {
        snapshot.cards.title(for: mode, persona: snapshot.persona)
    }

    // PM 2026-10-15: the fourth mode follows the user's identity card, so its spot and line branch on the card.
    static func spot(for mode: Mode, card: IdentityKind?, items: Set<HomeItem>) -> HomeSpot {
        switch mode {
        case .work: .work
        case .chill: .sofa
        case .boxing: cardSpot(card, items: items)
        case .money: .side
        }
    }

    static func cardSpot(_ card: IdentityKind?, items: Set<HomeItem>) -> HomeSpot {
        switch card {
        case .boxing: items.contains(.bag) ? .box : .shadowbox
        case .fitness: items.contains(.bench) ? .bench : .idle
        default: .idle
        }
    }

    /// What HAKU says when the mode changes; `title` is the card's name.
    static func modeLine(_ mode: Mode, title: String, card: IdentityKind?, items: Set<HomeItem>) -> String {
        switch mode {
        case .work: "\(title)。脑子开机中。"
        case .chill: "\(title)。今天到此为止。"
        case .boxing:
            switch card {
            case .boxing: items.contains(.bag) ? "\(title)。沙袋先挨几下。" : "\(title)。没沙袋，打空气也行。"
            case .fitness where items.contains(.bench): "\(title)。推几下。"
            default: "\(title)。准备出门。"
            }
        case .money: "\(title)。别打扰，也别走。"
        }
    }

    static func tapLines(spot: HomeSpot, low: Bool) -> [String] {
        switch spot {
        case .work: ["在忙。", "……别催。"]
        case .side: ["别看，还没做完。", "就差一点。可能。"]
        case .sofa: ["什么也不想做，这也算一种状态。", "遥控器在你那边。"]
        case .rest: ["……再五分钟。", "zzz"]
        case .box, .shadowbox: ["左、右、左。", "沙袋没惹我，是我今天比较硬。"]
        case .bench: ["推起来，放下去。就这样。", "重量？不告诉你。"]
        default:
            low ? ["电量不太够。", "……干嘛。"] : ["……干嘛。", "看我也不会多一罐。", "嗯。", "今天也没什么特别的。挺好。"]
        }
    }

    static func clock(_ date: Date = .now) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
