import Foundation
import Testing

@testable import HubCore

@Suite struct HomeBehaviorTests {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func home(
        mode: Mode?,
        card: IdentityKind? = .boxing,
        owned: Set<String> = [],
        placed: [String] = [],
        bedtime: Bedtime = .off
    ) -> HomeSnapshot {
        var room = RoomLayout(persona: .haku, deviceID: "phone")
        room.placements = placed.map { RoomPlacement(piece: $0, at: RoomCell(x: 1, y: 1)) }
        return HomeSnapshot(
            persona: .haku,
            mode: mode,
            cards: ModeCards(identity: card),
            cans: 0,
            owned: owned,
            wardrobe: Wardrobe(),
            energy: nil,
            vitals: HakuVitals(),
            bedtime: bedtime,
            today: [],
            room: room
        )
    }

    func beat(_ home: HomeSnapshot, _ moments: [HomeMoment] = [], at time: Date? = nil) -> HomeBeat? {
        HomeBehavior.beat(for: home, moments: moments, now: time ?? now, seed: 7)
    }

    @Test func eachModeHasItsSpot() {
        #expect(beat(home(mode: .work)) == HomeBeat(spot: .desk, action: .work, priority: .mode))
        #expect(beat(home(mode: .money)) == HomeBeat(spot: .desk, action: .sideHustle, priority: .mode))
        #expect(beat(home(mode: .chill)) == HomeBeat(spot: .sofa, action: .unwind, priority: .mode))
    }

    @Test func unsureSignalsKeepHerWhereSheIs() {
        #expect(beat(home(mode: nil)) == nil)
        #expect(beat(home(mode: .boxing, card: nil)) == nil)
    }

    @Test func theCardDayUsesBoughtGearOrPractises() {
        #expect(beat(home(mode: .boxing))?.action == .practise(.boxing))
        #expect(beat(home(mode: .boxing))?.spot == .sportsCorner)
        // Bought but in storage is the same as not there.
        #expect(beat(home(mode: .boxing, owned: ["room.bag"]))?.action == .practise(.boxing))
        let bag = beat(home(mode: .boxing, owned: ["room.bag"], placed: ["room.bag"]))
        #expect(bag == HomeBeat(spot: .item("room.bag"), action: .use("room.bag"), priority: .mode))
        // Another card's gear isn't hers to use.
        let tennis = home(mode: .boxing, card: .tennis, owned: ["room.bag"], placed: ["room.bag"])
        #expect(beat(tennis)?.action == .practise(.tennis))
    }

    @Test func bedtimeAndMomentsComeFirst() {
        let night = home(mode: .work, bedtime: .on)
        #expect(beat(night) == HomeBeat(spot: .bed, action: .sleep, priority: .bedtime))
        #expect(beat(home(mode: nil, bedtime: .on))?.spot == .bed)

        let change = UUID()
        let first = beat(night, [.offWork(change), .newItem("room.plant")])
        #expect(first == HomeBeat(spot: .sofa, action: .moment(.offWork(change)), priority: .moment))
        #expect(beat(night, [.newItem("room.plant")])?.spot == .item("room.plant"))
        #expect(beat(night, [.keepsake("haku.keepsake.gloves")])?.spot == .shelf)
        #expect(beat(home(mode: .work), [.celebration("a")])?.spot == .desk)
        #expect(beat(home(mode: nil), [.celebration("a")])?.spot == .sofa)
    }

    @Test func sheWandersToHomeItemsAtMostOnceASlot() {
        let items: Set<String> = ["room.plant", "room.bag", "room.bench"]
        let room = home(mode: .boxing, owned: items, placed: items.sorted())
        let slot = HomeBehavior.wanderSlot
        let start = (now.timeIntervalSinceReferenceDate / slot).rounded(.down) * slot
        var walkedSlots = 0
        for index in 0..<8 {
            let slotStart = start + Double(index) * slot
            let seconds = (0..<Int(slot)).filter { second in
                let time = Date(timeIntervalSinceReferenceDate: slotStart + Double(second))
                return beat(room, at: time)?.priority == .wander
            }
            if seconds.isEmpty { continue }
            walkedSlots += 1
            #expect(seconds.count == Int(HomeBehavior.wanderLength))
            #expect(seconds[seconds.count - 1] - seconds[0] == seconds.count - 1)
            let time = Date(timeIntervalSinceReferenceDate: slotStart + Double(seconds[0]))
            // The plant is her only home item: the bag belongs to the card, and the bench isn't sold yet.
            #expect(beat(room, at: time) == HomeBeat(spot: .item("room.plant"), action: .look, priority: .wander))
        }
        #expect(walkedSlots > 0)
        #expect(walkedSlots < 8)
    }

    @Test func noHomeItemsNoWalks() {
        let room = home(mode: .chill, owned: ["room.bag"], placed: ["room.bag"])
        let start = now.timeIntervalSinceReferenceDate
        let walks = (0..<3600).filter {
            beat(room, at: Date(timeIntervalSinceReferenceDate: start + Double($0)))?.priority == .wander
        }
        #expect(walks.isEmpty)
    }
}
