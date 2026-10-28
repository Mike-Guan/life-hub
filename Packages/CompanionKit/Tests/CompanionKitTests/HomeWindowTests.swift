#if os(iOS) || os(macOS)
import CoreGraphics
import HubCore
import Testing

@testable import CompanionKit

@Suite struct HomeWindowTests {
    @Test func theLineSaysOnlyWhereTheCharacterIs() {
        #expect(HomeWindow.line(.work, persona: .haku) == "HAKU 在书桌前")
        #expect(HomeWindow.line(.side, persona: .haku) == "HAKU 在书桌前")
        #expect(HomeWindow.line(.sofa, persona: .kuro) == "KURO 在沙发上")
        #expect(HomeWindow.line(.rest, persona: .haku) == "HAKU 在床上")
        #expect(HomeWindow.line(.practice, persona: .kuro) == "KURO 在活动身体")
        #expect(HomeWindow.line(.idle, persona: .haku) == "HAKU 在屋里")
    }

    @Test func theWindowCentresOnTheCharacterAndStaysInTheRoom() {
        let room = CGSize(width: 632, height: 604)
        let window = CGSize(width: 335, height: 124)
        let figure = CGRect(x: 300, y: 300, width: 40, height: 90)
        let middle = HomeWindow.origin(figure: figure, room: room, window: window)
        #expect(middle == CGPoint(x: 320 - 167.5, y: 345 - 62))
        let corner = HomeWindow.origin(figure: CGRect(x: 0, y: 0, width: 40, height: 90), room: room, window: window)
        #expect(corner == .zero)
        // A figure taller than the window keeps 8 points over its head.
        let tall = HomeWindow.origin(
            figure: CGRect(x: 300, y: 300, width: 40, height: 130), room: room, window: window)
        #expect(tall.y == 292)
        let far = HomeWindow.origin(figure: CGRect(x: 600, y: 560, width: 40, height: 40), room: room, window: window)
        #expect(far == CGPoint(x: 632 - 335, y: 604 - 124))
    }

    @Test func nightRunsFromSixInTheEveningToSixInTheMorning() throws {
        let calendar = Calendar.current
        let evening = DateComponents(year: 2026, month: 10, day: 28, hour: 17, minute: 59)
        let day = try #require(calendar.date(from: evening))
        #expect(!HomeModel.isNight(at: day))
        #expect(HomeModel.isNight(at: day.addingTimeInterval(60)))
        let morning = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 6)))
        #expect(!HomeModel.isNight(at: morning))
        #expect(HomeModel.isNight(at: morning.addingTimeInterval(-60)))
    }
}
#endif
