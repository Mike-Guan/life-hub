import Foundation

// 家 区域规划 v0 (PM 2026-10-17): each room item stands in one zone of the home page. The shop's preview names
// it. The furniture and the reward shelf are zones too, but nothing is bought for them, so they have no case yet.
// UI 审核 2026-10-17: the bench stands against the wall since #500, so the sports floor reads "by the wall".
/// A part of the home page where room items stand.
public enum RoomZone: String, CaseIterable, Sendable {
    /// The sports floor: one piece of floor gear, such as the bag or the bench.
    case sportFloor
    /// The sports wall: two hooks for gear that hangs or leans, such as the snowboard.
    case sportWall
    /// On the desk: small things such as a mug or a cactus.
    case desk
    /// Next to the sofa: the speaker, cushions.
    case sofaSide
    /// The front left corner: a plant or flowers.
    case corner

    /// Whether the zone holds sports gear, which the character never uses on her own and never pays cans.
    public var isSports: Bool { self == .sportFloor || self == .sportWall }
}

extension ShopItem {
    private static let zones: [String: RoomZone] = [
        "room.plant": .corner,
        "room.bag": .sportFloor,
        "room.bench": .sportFloor,
        "room.snowboard": .sportWall,
        "haku.weekly.room.cactus": .desk,
        "haku.weekly.room.speaker": .sofaSide,
        "kuro.room.flower": .corner,
        "kuro.room.lamp": .desk,
        "kuro.room.bench": .sportFloor,
        "kuro.room.snowboard": .sportWall,
        "kuro.weekly.room.succulent": .desk,
        "kuro.weekly.room.cloud": .sofaSide,
        "kuro.weekly.room.nightlight": .sofaSide,
    ]

    /// The zone of the home page the item stands in; `nil` for items that aren't room items.
    public var zone: RoomZone? { Self.zones[id] }
}
