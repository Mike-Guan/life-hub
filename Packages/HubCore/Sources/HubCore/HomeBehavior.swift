import Foundation

// 家 执行计划 v0 §3. The home page asks these rules where the character goes and what she does; the scene only
// plays it. Dragging and tapping (P0) stay in the scene, which holds them for about 30 seconds and then asks again.

/// A one-time moment the home page plays once, then drops.
public enum HomeMoment: Hashable, Sendable {
    /// Work just ended while the home page was open; the id is the mode change's.
    case offWork(UUID)
    /// A room item just arrived.
    case newItem(String)
    /// A keepsake was just earned.
    case keepsake(String)
    /// A celebration event, by its id.
    case celebration(String)
}

/// Where in the room the character stands.
public enum HomePlace: Hashable, Sendable {
    case desk, sofa, bed
    /// The reward shelf.
    case shelf
    /// The sports corner, with no gear of the card's own.
    case sportsCorner
    /// Next to a placed item, by its id.
    case item(String)
}

/// What the character does at a spot.
public enum HomeAction: Hashable, Sendable {
    case work
    case sideHustle
    case unwind
    case sleep
    /// Uses the identity card's own gear, by item id.
    case use(String)
    /// Practises the identity card's sport with nothing, such as air punches.
    case practise(IdentityKind)
    /// Has a look at an item for a while.
    case look
    case moment(HomeMoment)
}

/// The rule that decided a beat: P1 moment, P2 bedtime, P3 mode or P5 wander.
public enum HomePriority: Sendable {
    case moment, bedtime, mode, wander
}

/// Where the character is and what she does there, and which rule chose it.
public struct HomeBeat: Equatable, Sendable {
    public var spot: HomePlace
    public var action: HomeAction
    public var priority: HomePriority

    public init(spot: HomePlace, action: HomeAction, priority: HomePriority) {
        self.spot = spot
        self.action = action
        self.priority = priority
    }
}

/// The home page's behavior rules.
public enum HomeBehavior {
    /// Length of a wander slot: at most one walk to a home item in each.
    public static let wanderSlot: TimeInterval = 15 * 60
    /// How long a walk to a home item lasts.
    public static let wanderLength: TimeInterval = 30

    /// What the character does now.
    /// - Parameters:
    ///   - home: the home page's snapshot.
    ///   - moments: one-time moments not yet played, oldest first.
    ///   - now: the current time.
    ///   - seed: the day's seed, so the same day wanders the same way.
    /// - Returns: the beat, or `nil` when the signals can't tell, so the character stays where she is.
    public static func beat(for home: HomeSnapshot, moments: [HomeMoment] = [], now: Date, seed: UInt64) -> HomeBeat? {
        if let moment = moments.first {
            return HomeBeat(spot: spot(for: moment, home: home), action: .moment(moment), priority: .moment)
        }
        if home.bedtime == .on {
            return HomeBeat(spot: .bed, action: .sleep, priority: .bedtime)
        }
        guard let base = modeBeat(for: home) else { return nil }
        if let item = wander(in: home, now: now, seed: seed) {
            return HomeBeat(spot: .item(item), action: .look, priority: .wander)
        }
        return base
    }

    private static func spot(for moment: HomeMoment, home: HomeSnapshot) -> HomePlace {
        switch moment {
        case .offWork: .sofa
        case .newItem(let id): .item(id)
        case .keepsake: .shelf
        case .celebration: modeBeat(for: home)?.spot ?? .sofa
        }
    }

    /// P3: each mode has its spot. On the identity card's day she uses the card's gear if Mike bought it.
    private static func modeBeat(for home: HomeSnapshot) -> HomeBeat? {
        switch home.mode {
        case .work: return HomeBeat(spot: .desk, action: .work, priority: .mode)
        case .money: return HomeBeat(spot: .desk, action: .sideHustle, priority: .mode)
        case .chill: return HomeBeat(spot: .sofa, action: .unwind, priority: .mode)
        case .boxing:
            guard let card = home.cards.identity else { return nil }
            if let gear = placed(in: home).first(where: { ShopItem.item($0)?.card == card }) {
                return HomeBeat(spot: .item(gear), action: .use(gear), priority: .mode)
            }
            return HomeBeat(spot: .sportsCorner, action: .practise(card), priority: .mode)
        case nil: return nil
        }
    }

    // P5: sports gear is never used on her own, since that would hint the user should train.
    /// The home item to look at now, if this slot has a walk and it is under way.
    private static func wander(in home: HomeSnapshot, now: Date, seed: UInt64) -> String? {
        let items = placed(in: home).filter { ShopItem.item($0)?.zone?.isSports == false }
        guard !items.isEmpty else { return nil }
        let time = now.timeIntervalSinceReferenceDate
        let slot = (time / wanderSlot).rounded(.down)
        var random = SplitMix64(seed: seed ^ UInt64(bitPattern: Int64(slot)))
        // Half the slots have a walk, starting anywhere it still ends inside the slot.
        guard random.next() % 2 == 0 else { return nil }
        let start = slot * wanderSlot + Double(random.next() % UInt64(wanderSlot - wanderLength))
        guard time >= start, time < start + wanderLength else { return nil }
        return items[Int(random.next() % UInt64(items.count))]
    }

    /// The owned room items standing in the room, sorted.
    private static func placed(in home: HomeSnapshot) -> [String] {
        let standing = Set(home.room.placements.filter { !$0.isStored }.map(\.piece))
        return home.owned.filter { standing.contains($0) && ShopItem.item($0)?.slot == .room }.sorted()
    }
}

/// A small seeded generator, so a day's choices repeat.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
