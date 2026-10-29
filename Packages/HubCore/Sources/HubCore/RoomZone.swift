import Foundation

// 家 区域规划 v0 (PM 2026-10-17): each room item stands in one zone of the home page. The shop's preview names
// it. The furniture and the reward shelf are zones too, but nothing is bought for them, so they have no case yet.
// Rugs have no zone: one changes the rug's style (`RoomLayout.rug`).
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
    /// The left wall over the desk: one poster, in place of the two default ones.
    case posterWall

    /// Whether the zone holds sports gear, which the character never uses on her own and never pays cans.
    public var isSports: Bool { self == .sportFloor || self == .sportWall }

    /// How many items the zone holds at once.
    public var capacity: Int {
        switch self {
        case .sportWall, .desk: 2
        case .sportFloor, .sofaSide, .corner, .posterWall: 1
        }
    }
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
        // 商店扩充 v1 §2.
        "haku.room.poster.arcade": .posterWall,
        "haku.room.poster.city": .posterWall,
        "haku.room.lamp.clip": .desk,
        "haku.room.headphones": .desk,
        "haku.room.gamepad": .desk,
        "haku.room.cube": .desk,
        "haku.room.comics": .sofaSide,
        "haku.room.fan": .sofaSide,
        "haku.room.monstera": .corner,
        "haku.room.skateboard": .corner,
        "kuro.room.poster.cat": .posterWall,
        "kuro.room.poster.stars": .posterWall,
        "kuro.room.clock.cat": .desk,
        "kuro.room.jar": .desk,
        "kuro.room.mug.strawberry": .desk,
        "kuro.room.mirror": .desk,
        "kuro.room.yarn": .sofaSide,
        "kuro.room.plush": .sofaSide,
        "kuro.room.sakura": .corner,
        "kuro.room.easel": .corner,
        "room.mat": .sportFloor,
        "room.rope": .sportWall,
        "room.mirror.dance": .sportWall,
        "room.stand.music": .corner,
        "kuro.room.mat": .sportFloor,
        "kuro.room.rope": .sportWall,
        "kuro.room.mirror.dance": .sportWall,
        "kuro.room.stand.music": .corner,
    ]

    /// The zone of the home page the item stands in; `nil` for items that aren't room items.
    public var zone: RoomZone? { Self.zones[id] }
}
