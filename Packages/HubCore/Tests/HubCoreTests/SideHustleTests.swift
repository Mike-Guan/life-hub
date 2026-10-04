import Foundation
import Testing

@testable import HubCore

@MainActor
@Suite struct SideHustleTests {
    let at = Date(timeIntervalSince1970: 1_790_000_000)
    let hour: TimeInterval = 60 * 60

    @Test func oldMoneyChangesAreVibeCoding() throws {
        let json = #"{"id":"\#(UUID().uuidString)","mode":"money","at":"2026-10-04T00:00:00Z"}"#
        let change = try HubJSON.decoder().decode(ModeChange.self, from: Data(json.utf8))
        #expect(change.sideHustle == .vibeCoding)
        #expect(SideHustle(tag: "future") == .vibeCoding)
        #expect(ModeChange(mode: .work, tag: "shooting", deviceID: "t").sideHustle == nil)
    }

    @Test func tapsCycleInOrder() {
        #expect(SideHustle.vibeCoding.next == .shooting)
        #expect(SideHustle.shooting.next == .operating)
        #expect(SideHustle.operating.next == .vibeCoding)
        #expect(SideHustle.vibeCoding.moment == .vibeCoding)
        #expect(SideHustle.operating.moment == .shooting)
    }

    @Test func cyclingRecordsAManualStateChange() {
        let store = ModeStore(fileURL: nil, deviceID: "t")
        let outside = store.cycleSideHustle(at: at)
        #expect(!outside)
        store.switchTo(.work, at: at)
        let atWork = store.cycleSideHustle(at: at + hour)
        #expect(!atWork)

        store.switchTo(.money, at: at + 2 * hour)
        #expect(store.sideHustle == .vibeCoding)
        let cycled = store.cycleSideHustle(at: at + 3 * hour)
        #expect(cycled)
        #expect(store.sideHustle == .shooting)
        #expect(store.log.current?.source == .manual)
        #expect(store.log.current?.tag == "shooting")
        // A 副业 button tap goes back to the default state.
        store.switchTo(.money, at: at + 4 * hour)
        #expect(store.sideHustle == .vibeCoding)
        #expect(store.log.active.count == 4)
    }

    @Test func quickTapsCorrectEachOther() {
        let store = ModeStore(fileURL: nil, deviceID: "t")
        store.switchTo(.money, at: at)
        for tap in 1...3 { store.cycleSideHustle(at: at + hour + Double(tap)) }
        // Three quick taps come back to vibe coding and leave only the first switch.
        #expect(store.sideHustle == .vibeCoding)
        #expect(store.log.active.count == 1)
    }

    @Test func codingFocusFollowsTheHold() {
        let store = ModeStore(fileURL: nil, deviceID: "t")
        store.switchTo(.money, tag: SideHustle.shooting.rawValue, at: at)
        #expect(store.autoSwitch(.codingFocus, now: at + hour) == nil)
        let decision = store.autoSwitch(.codingFocus, now: at + 3 * hour)
        #expect(decision?.reason == "编程专注模式开了")
        #expect(store.sideHustle == .vibeCoding)
        #expect(store.log.current?.source == .focus)
        // Already vibe coding: nothing new.
        #expect(store.autoSwitch(.codingFocus, now: at + 4 * hour) == nil)
        #expect(store.log.active.count == 2)
    }

    @Test func cansPileUpEveryHalfHour() {
        #expect(SideHustle.codingCans(since: at, now: at - 60) == 0)
        #expect(SideHustle.codingCans(since: at, now: at + 29 * 60) == 0)
        #expect(SideHustle.codingCans(since: at, now: at + 30 * 60) == 1)
        #expect(SideHustle.codingCans(since: at, now: at + 5 * hour) == 3)
    }

    @Test func snapshotCarriesTheState() {
        let store = ModeStore(fileURL: nil, deviceID: "t")
        store.switchTo(.money, tag: SideHustle.operating.rawValue, at: at)
        let snapshot = store.snapshot(now: at)
        #expect(snapshot.sideHustle == .operating)
        let change = ModeChange(mode: .money, tag: SideHustle.shooting.rawValue, at: at + hour, deviceID: "t")
        let applied = snapshot.applying(.mode(change))
        #expect(applied.sideHustle == .shooting)
        #expect(applied.since == at + hour)
        let work = ModeChange(mode: .work, at: at + 2 * hour, deviceID: "t")
        #expect(applied.applying(.mode(work)).sideHustle == nil)
    }
}
