import Foundation

// 商店完整目录 v0 §10.1: each room item stands in one zone of the home page. The shop's preview names it.
// UI 审核 2026-10-17: the bench stands against the wall since #500, so the sports corner reads "by the wall".
/// A part of the home page where room items stand.
public enum RoomZone: String, CaseIterable, Sendable {
    /// The sports corner, by the wall: floor gear such as the bag and the bench.
    case sportsCorner
    /// The sports wall: gear that hangs or leans, such as the snowboard.
    case sportsWall
    /// On the desk: small things such as a mug or a cactus.
    case desk
    /// Next to the sofa: the speaker, cushions.
    case sofaSide
    /// The front left corner: plants and flowers.
    case frontCorner

    /// Whether the zone holds sports gear, which the character never uses on her own and never pays cans.
    public var isSports: Bool { self == .sportsCorner || self == .sportsWall }
}

extension ShopItem {
    private static let zones: [String: RoomZone] = [
        "room.plant": .frontCorner,
        "room.bag": .sportsCorner,
        "haku.weekly.room.cactus": .desk,
        "haku.weekly.room.speaker": .sofaSide,
        "kuro.room.flower": .frontCorner,
        "kuro.room.lamp": .desk,
        "kuro.weekly.room.succulent": .desk,
        "kuro.weekly.room.cloud": .sofaSide,
        "kuro.weekly.room.nightlight": .sofaSide,
    ]

    /// The zone of the home page the item stands in; `nil` for items that aren't room items.
    public var zone: RoomZone? { Self.zones[id] }
}
