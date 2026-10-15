import Foundation
import Testing

@testable import HubCore

@Suite struct EventSlotTests {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func anEventStaysForItsHoldThenClears() {
        var slot = EventSlot()
        slot.raise(.offWork(id: "2026-10-15"), at: start)
        var cleared = slot.expire(at: start.addingTimeInterval(EventSlot.hold - 1))
        #expect(!cleared)
        #expect(slot.event == .offWork(id: "2026-10-15"))
        cleared = slot.expire(at: start.addingTimeInterval(EventSlot.hold))
        #expect(cleared)
        #expect(slot.event == nil)
        #expect(slot.raisedAt == nil)
        // An empty slot has nothing to clear.
        cleared = slot.expire(at: start.addingTimeInterval(EventSlot.hold * 2))
        #expect(!cleared)
    }

    @Test func aNewEventStartsItsOwnHold() {
        var slot = EventSlot()
        slot.raise(.offWork(id: "2026-10-15"), at: start)
        let later = start.addingTimeInterval(20)
        slot.raise(.celebrate(id: "run", kind: .running), at: later)
        // The first event's hold is over, but the second one's isn't.
        var cleared = slot.expire(at: start.addingTimeInterval(EventSlot.hold))
        #expect(!cleared)
        #expect(slot.event == .celebrate(id: "run", kind: .running))
        cleared = slot.expire(at: later.addingTimeInterval(EventSlot.hold))
        #expect(cleared)
    }

    @Test func holdOutlastsTheLongestOneOffAnimation() {
        // The stretch after a long sit runs 6 s, the longest one-off move.
        #expect(EventSlot.hold > 6)
    }
}
