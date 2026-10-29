import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct KuroThoughtsTests {
    @Test func scrollingTanglesHerAndALowDayRainsOnHer() {
        #expect(KuroThought.pick(energy: 50, need: .couchScroll) == .tangle)
        #expect(KuroThought.pick(energy: 10, need: .couchScroll) == .tangle)
        #expect(KuroThought.pick(energy: 10, need: nil) == .rain)
        #expect(KuroThought.pick(energy: 50, need: nil) == nil)
        #expect(KuroThought.pick(energy: nil, need: .slacking) == nil)
    }

    @Test func eachThoughtShowsOnceADay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let morning = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 9)))
        #expect(KuroThought.newDay(at: morning, last: "", calendar: calendar) == "2026-10-28")
        #expect(KuroThought.newDay(at: morning, last: "2026-10-28", calendar: calendar) == nil)
        #expect(KuroThought.newDay(at: morning, last: "2026-10-27", calendar: calendar) == "2026-10-28")
    }

    @Test func theBubbleFadesInAndOutWithinItsLength() {
        let length = KuroThought.rain.duration(reduceMotion: false)
        #expect(KuroThoughtBubble.fade(0, length: length) == 0)
        #expect(KuroThoughtBubble.fade(2, length: length) == 1)
        #expect(KuroThoughtBubble.fade(length, length: length) == 0)
        #expect(KuroThought.tangle.duration(reduceMotion: true) < KuroThought.tangle.duration(reduceMotion: false))
    }
}
