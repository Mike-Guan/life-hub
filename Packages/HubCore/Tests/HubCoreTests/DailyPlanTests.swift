import Foundation
import Testing

@testable import HubCore

@Suite struct DailyPlanTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    // 2026-10-05 is a Monday. Fixtures are made up.
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    func task(_ id: String, at start: Date, done: Bool = false, focus: Bool = false) -> DailyOccurrence {
        DailyOccurrence(
            id: id,
            title: "Sample",
            start: start,
            end: start.addingTimeInterval(3600),
            done: done,
            focus: focus,
            planned: true,
            prop: .gymBag
        )
    }

    @Test func categoriesPickTheProp() throws {
        #expect(DailyProp(category: "learning") == .headphones)
        #expect(DailyProp(category: "health") == .gymBag)
        #expect(DailyProp(category: "errands") == .bag)
        #expect(DailyProp(category: "home") == .bag)
        #expect(DailyProp(category: "social") == .note)
        #expect(DailyProp(category: "anything new") == .note)
        let json = #"{ "id" : "c", "category" : "health", "date" : "2026-10-05", "start" : 600, "end" : 660 }"#
        let decoded = try JSONDecoder().decode(DailyTask.self, from: Data(json.utf8))
        #expect(decoded.category == "health")
        #expect(decoded.occurrence(on: date(5, 9), calendar: calendar)?.prop == .gymBag)
        let bare = try JSONDecoder().decode(DailyTask.self, from: Data(#"{ "id" : "d" }"#.utf8))
        #expect(bare.category == "personal")
    }

    @Test func nextIsTodaysFirstOpenTask() {
        let plan = DailyPlan(occurrences: [
            task("done", at: date(5, 17), done: true),
            task("later", at: date(5, 18)),
            task("tomorrow", at: date(6, 9)),
        ])
        #expect(plan.next(after: date(5, 16), calendar: calendar)?.id == "later")
        // Tomorrow's task doesn't show tonight.
        #expect(plan.next(after: date(5, 18, 30), calendar: calendar) == nil)
        #expect(plan.next(after: date(6, 8), calendar: calendar)?.id == "tomorrow")
    }

    @Test func nextLineShowsTheTitleOnlyWhenAsked() {
        let next = task("t", at: date(5, 18))
        #expect(DailyAgenda.nextLine(next, title: true, calendar: calendar) == "下一件 18:00 Sample")
        #expect(DailyAgenda.nextLine(next, title: false, calendar: calendar) == "下一件 18:00")
        var untitled = next
        untitled.title = ""
        #expect(DailyAgenda.nextLine(untitled, title: true, calendar: calendar) == "下一件 18:00")
    }

    @Test func cueIsSoonThenNowThenNothing() {
        let plan = DailyPlan(occurrences: [task("t", at: date(5, 18))])
        #expect(plan.cue(at: date(5, 17, 44)) == nil)
        #expect(plan.cue(at: date(5, 17, 45)) == DailyCue(stage: .soon, prop: .gymBag, id: "t"))
        #expect(plan.cue(at: date(5, 18)) == DailyCue(stage: .now, prop: .gymBag, id: "t"))
        #expect(plan.cue(at: date(5, 18, 10)) == nil)
        let done = DailyPlan(occurrences: [task("t", at: date(5, 18), done: true)])
        #expect(done.cue(at: date(5, 17, 50)) == nil)
        #expect(plan.times.contains(date(5, 17, 45)) && plan.times.contains(date(5, 18, 10)))
    }

    @Test func aTaskWithinTheHourChangesTheCouchInvite() {
        let plan = DailyPlan(occurrences: [task("t", at: date(5, 18))])
        #expect(plan.hasTask(within: DailyAgenda.inviteLead, after: date(5, 17)))
        #expect(!plan.hasTask(within: DailyAgenda.inviteLead, after: date(5, 16, 59)))
        #expect(!plan.hasTask(within: DailyAgenda.inviteLead, after: date(5, 18, 1)))
        let soon = NeedEngine.inviteText(for: .couchScroll, taskSoon: true)
        #expect(soon != NeedEngine.inviteText(for: .couchScroll))
        #expect(soon.count <= 14)
        #expect(NeedEngine.inviteText(for: .gymDay, taskSoon: true) == NeedEngine.inviteText(for: .gymDay))
    }

    @Test func onlyNewlyDoneTasksCelebrate() {
        let first = [task("a", at: date(5, 9), done: true), task("b", at: date(5, 18))]
        let start = DailyAgenda.newlyDone(in: first, seen: nil)
        #expect(start.event == nil)
        #expect(start.seen == ["a"])
        let later = [task("a", at: date(5, 9), done: true), task("b", at: date(5, 18), done: true, focus: true)]
        let next = DailyAgenda.newlyDone(in: later, seen: start.seen)
        #expect(next.event == .taskDone(id: "b", focus: true))
        #expect(DailyAgenda.newlyDone(in: later, seen: next.seen).event == nil)
    }

    @Test func planRoundTripsThroughDefaults() throws {
        let defaults = try #require(UserDefaults(suiteName: "daily-\(UUID().uuidString)"))
        #expect(DailyPlan.stored(in: defaults) == nil)
        let plan = DailyPlan(occurrences: [task("t", at: date(5, 18))])
        plan.store(in: defaults)
        #expect(DailyPlan.stored(in: defaults) == plan)
        DailyPlan.clear(in: defaults)
        #expect(DailyPlan.stored(in: defaults) == nil)
    }
}
