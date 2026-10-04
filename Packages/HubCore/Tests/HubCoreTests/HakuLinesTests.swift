import Foundation
import Testing

@testable import HubCore

@Suite struct HakuLinesTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour)) ?? .distantPast
    }

    @Test func dailyScenesLastAWeekAndLinesAreShort() {
        let weekly: Set<LineScene> = [.boxing, .boxingWarmup]
        for scene in LineScene.allCases {
            let lines = HakuLines.library[scene] ?? []
            #expect(lines.count >= (weekly.contains(scene) ? 3 : 7), "\(scene)")
            #expect(Set(lines).count == lines.count, "\(scene)")
            #expect(lines.allSatisfy { $0.count <= 14 }, "\(scene)")
        }
    }

    @Test func aLineStaysAllDayAndRotatesThroughTheScene() {
        let morning = HakuLines.line(.chill, at: date(5, 6), calendar: calendar)
        #expect(HakuLines.line(.chill, at: date(5, 23), calendar: calendar) == morning)
        // Before 05:00 still belongs to the day before.
        #expect(HakuLines.line(.chill, at: date(6, 4), calendar: calendar) == morning)

        let count = HakuLines.library[.chill]?.count ?? 0
        let week = (0..<count).map { HakuLines.line(.chill, at: date(5 + $0, 12), calendar: calendar) }
        #expect(Set(week).count == count)
        #expect(HakuLines.line(.chill, at: date(5 + count, 12), calendar: calendar) == morning)
    }

    @Test func sceneFollowsBedtimeThenNeedThenEnergyThenMode() {
        #expect(HakuLines.scene(mode: .work, need: .couchScroll, energy: .low, bedtime: .on) == .bedtime)
        #expect(HakuLines.scene(mode: .work, need: .couchScroll, energy: .low, bedtime: .off) == .couchScroll)
        #expect(HakuLines.scene(mode: .chill, need: .boxingWarmup, energy: nil, bedtime: .off) == .boxingWarmup)
        #expect(HakuLines.scene(mode: .work, need: nil, energy: .low, bedtime: .off) == .lowEnergy)
        #expect(HakuLines.scene(mode: .money, need: nil, energy: .full, bedtime: .off) == .money)
        #expect(HakuLines.scene(mode: .boxing, need: nil, energy: nil, bedtime: .off) == .boxing)
        #expect(HakuLines.scene(mode: .work, need: nil, energy: .okay, bedtime: .off) == .work)
        #expect(HakuLines.scene(mode: .chill, need: nil, energy: nil, bedtime: .off) == .chill)
        #expect(HakuLines.scene(mode: nil, need: nil, energy: nil, bedtime: .off) == nil)
    }
}
