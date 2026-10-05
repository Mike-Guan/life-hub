import Foundation
import Testing

@testable import HubCore

@Suite struct DailySceneTests {
    func scene(_ title: String) -> DailyScene? {
        SceneTable.standard.scene(for: title)
    }

    // Titles are made up.
    @Test func everySceneHasATitleThatPicksIt() {
        let titles: [DailyScene: String] = [
            .coffee: "和同事喝咖啡", .meal: "ランチ", .drinks: "居酒屋", .meeting: "周会 1on1",
            .call: "Zoom with A", .grocery: "去超市", .shopping: "优衣库", .cook: "做饭",
            .haircut: "理发", .doctor: "歯医者", .gym: "练腿", .run: "晨跑 5km", .walk: "散步",
            .photo: "外拍", .friends: "见朋友",
        ]
        for (expected, title) in titles {
            #expect(scene(title) == expected, "\(title)")
        }
        #expect(Set(titles.keys) == Set(DailyScene.allCases))
    }

    @Test func caseAndWidthDoNotMatter() {
        #expect(scene("ＧＹＭ") == .gym)
        #expect(scene("Morning RUN") == .run)
        #expect(scene("ｍｔｇ") == .meeting)
        #expect(scene("スーパー") == .grocery)
    }

    @Test func englishMatchesWholeWords() {
        #expect(scene("brunch") == nil)
        #expect(scene("barber") == nil)
        #expect(scene("gym打卡") == .gym)
        #expect(scene("call mom") == .call)
    }

    @Test func groceryAndShoppingAndTheFirstRowWins() {
        #expect(scene("買い物") == .shopping)
        #expect(scene("買い物 スーパー") == .grocery)
        #expect(scene("买点菜") == .grocery)
        #expect(scene("做菜") == .cook)
        #expect(scene("咖啡 开会") == .coffee)
        #expect(scene("约拍") == .photo)
        #expect(scene("预约") == nil)
    }

    @Test func noMatchKeepsTheProp() throws {
        #expect(scene("写周报") == nil)
        #expect(scene("") == nil)
        let task = DailyTask(id: "a", title: "去健身房", date: "2026-10-05", start: 600, end: 660)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 9)))
        let occurrence = try #require(task.occurrence(on: day, calendar: calendar))
        #expect(occurrence.scene == .gym)
        let plan = DailyPlan(occurrences: [occurrence])
        #expect(plan.cue(at: occurrence.start)?.scene == .gym)
        let plain = DailyTask(id: "b", title: "写周报", date: "2026-10-05", start: 600, end: 660)
        #expect(plain.occurrence(on: day, calendar: calendar)?.scene == nil)
    }

    @Test func aStoredPlanWithoutScenesStillReads() throws {
        let json =
            #"{"id":"a","title":"","start":0,"end":60,"done":false,"focus":false,"planned":true,"prop":"note"}"#
        let occurrence = try JSONDecoder().decode(DailyOccurrence.self, from: Data(json.utf8))
        #expect(occurrence.scene == nil)
    }
}
