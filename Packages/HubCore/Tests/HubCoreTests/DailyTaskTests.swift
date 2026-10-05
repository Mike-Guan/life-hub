import Foundation
import Testing

@testable import HubCore

@Suite struct DailyTaskTests {
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

    func decode(_ json: String) throws -> DailyTask {
        try JSONDecoder().decode(DailyTask.self, from: Data(json.utf8))
    }

    @Test func decodesAOneOffTaskWrittenByTheIPhone() throws {
        let task = try decode(
            """
            {
              "category" : "health", "colorMode" : "category", "completedDates" : [ ],
              "createdAt" : "2026-10-05T08:00:00Z", "date" : "2026-10-05", "done" : false, "end" : 1350,
              "focus" : true, "focusDates" : [ ], "id" : "0F3C2A9E-1B7D-4C55-9E21-6A0B8D3F1C42", "notes" : "",
              "recurrence" : "none", "schemaVersion" : 2, "start" : 1290, "title" : "Sample workout",
              "updatedAt" : "2026-10-05T09:12:00Z", "updatedBy" : "iphone-SAMPLE", "url" : ""
            }
            """
        )
        #expect(task.id == "0F3C2A9E-1B7D-4C55-9E21-6A0B8D3F1C42")
        #expect(task.title == "Sample workout")
        #expect(task.date == "2026-10-05")
        #expect(task.start == 1290 && task.end == 1350)
        #expect(task.recurrence == .none && task.focus && !task.done)
        #expect(task.createdAt == DailyTask.date(from: "2026-10-05T08:00:00Z"))
        #expect(task.deletedAt == nil)
    }

    @Test func decodesARepeatingTaskWrittenByTheMac() throws {
        let task = try decode(
            """
            {
              "category" : "learning", "colorMode" : "category", "colorToken" : null,
              "completedDates" : [ "2026-10-01", "2026-10-02" ], "createdAt" : "2026-09-30T22:00:00.000Z",
              "date" : "2026-09-30", "deletedAt" : null, "done" : false, "end" : 480, "focus" : false,
              "focusDates" : [ "2026-10-02" ], "id" : "sample-weekday-task", "notes" : "",
              "recurrence" : "weekdays", "schemaVersion" : 2, "start" : 450, "title" : "Sample morning reading",
              "updatedAt" : "2026-10-02T23:10:00.000Z", "updatedBy" : "mac-SAMPLE", "url" : ""
            }
            """
        )
        #expect(task.recurrence == .weekdays)
        #expect(task.completedDates == ["2026-10-01", "2026-10-02"])
        #expect(task.focusDates == ["2026-10-02"])
        #expect(task.createdAt == DailyTask.date(from: "2026-09-30T22:00:00Z"))
        #expect(task.deletedAt == nil)
    }

    @Test func missingNullAndUnknownFieldsGetDefaults() throws {
        let bare = try decode(#"{ "id" : "x" }"#)
        #expect(bare == DailyTask(id: "x", date: nil, start: nil, end: nil))
        let odd = try decode(#"{ "id" : "y", "title" : null, "recurrence" : "monthly", "done" : "yes" }"#)
        #expect(odd.title == "" && odd.recurrence == .none && !odd.done)
        #expect(throws: DecodingError.self) { try decode(#"{ "title" : "no id" }"#) }
    }

    @Test func oneOffTasksHappenOnTheirDayOnly() throws {
        let task = DailyTask(id: "a", title: "A", date: "2026-10-05", start: 1290, end: 1350)
        let occurrence = try #require(task.occurrence(on: date(5, 12), calendar: calendar))
        #expect(occurrence.id == "a")
        #expect(occurrence.start == date(5, 21, 30))
        #expect(occurrence.end == date(5, 22, 30))
        #expect(task.occurrence(on: date(6, 12), calendar: calendar) == nil)
        // No time, or deleted: not on the timeline.
        let inbox = DailyTask(id: "b", date: "2026-10-05", start: nil, end: nil)
        #expect(inbox.occurrence(on: date(5, 12), calendar: calendar) == nil)
        var deleted = task
        deleted.deletedAt = date(5, 9)
        #expect(deleted.occurrence(on: date(5, 12), calendar: calendar) == nil)
    }

    @Test func anEndPastMidnightEndsTheNextDay() throws {
        let late = DailyTask(id: "late", date: "2026-10-05", start: 1380, end: 1500)
        let occurrence = try #require(late.occurrence(on: date(5, 12), calendar: calendar))
        #expect(occurrence.end == date(6, 1))
    }

    @Test func repeatingTasksExpandFromTheirFirstDay() {
        func happens(_ recurrence: DailyTask.Recurrence, on day: Int) -> Bool {
            let task = DailyTask(id: "r", date: "2026-10-05", start: 450, end: 480, recurrence: recurrence)
            return task.occurrence(on: date(day, 12), calendar: calendar) != nil
        }
        // 10-04 Sunday, 10-05 Monday (first day), 10-10 Saturday, 10-12 Monday.
        #expect(!happens(.daily, on: 4))
        #expect(happens(.daily, on: 10))
        #expect(happens(.weekdays, on: 5) && !happens(.weekdays, on: 10))
        #expect(happens(.weekly, on: 12) && !happens(.weekly, on: 6))
    }

    @Test func repeatingTasksAreDoneAndFocusedPerDay() throws {
        let task = DailyTask(
            id: "r",
            date: "2026-10-01",
            start: 450,
            end: 480,
            recurrence: .daily,
            done: true,
            completedDates: ["2026-10-05"],
            focusDates: ["2026-10-06"]
        )
        let monday = try #require(task.occurrence(on: date(5, 12), calendar: calendar))
        #expect(monday.id == "r:2026-10-05" && monday.done && !monday.focus)
        let tuesday = try #require(task.occurrence(on: date(6, 12), calendar: calendar))
        #expect(tuesday.id == "r:2026-10-06" && !tuesday.done && tuesday.focus)
    }

    @Test func plannedMeansCreatedBeforeTheStart() throws {
        let ahead = DailyTask(id: "p", date: "2026-10-05", start: 1080, end: 1140, createdAt: date(5, 9))
        #expect(try #require(ahead.occurrence(on: date(5, 12), calendar: calendar)).planned)
        let onTheSpot = DailyTask(id: "q", date: "2026-10-05", start: 1080, end: 1140, createdAt: date(5, 18, 5))
        #expect(try #require(onTheSpot.occurrence(on: date(5, 12), calendar: calendar)).planned == false)
        let unknown = DailyTask(id: "u", date: "2026-10-05", start: 1080, end: 1140)
        #expect(try #require(unknown.occurrence(on: date(5, 12), calendar: calendar)).planned == false)
    }

    @Test func occurrencesCoverYesterdayToTomorrowAndNextSkipsDone() throws {
        let tasks = [
            DailyTask(id: "old", date: "2026-10-03", start: 600, end: 660),
            DailyTask(id: "y", date: "2026-10-04", start: 600, end: 660),
            DailyTask(id: "done", date: "2026-10-05", start: 1080, end: 1140, done: true),
            DailyTask(id: "t", date: "2026-10-05", start: 1110, end: 1140),
            DailyTask(id: "m", date: "2026-10-06", start: 540, end: 600),
            DailyTask(id: "far", date: "2026-10-07", start: 540, end: 600),
        ]
        let list = DailyAgenda.occurrences(tasks, now: date(5, 17), calendar: calendar)
        #expect(list.map(\.id) == ["y", "done", "t", "m"])
        #expect(DailyAgenda.next(in: list, after: date(5, 17))?.id == "t")
        #expect(DailyAgenda.next(in: list, after: date(5, 18, 40))?.id == "t")
        #expect(DailyAgenda.next(in: list, after: date(5, 19))?.id == "m")
    }

    func done(_ id: String) -> DailyOccurrence {
        DailyOccurrence(
            id: id,
            title: "",
            start: date(5, 18),
            end: date(5, 19),
            done: true,
            focus: false,
            planned: true
        )
    }

    @Test func plannedTasksDoneEarnACanEachUpToThreeADay() {
        var ledger = CanLedger()
        let first = DailyAgenda.wins(in: [done("a"), done("b")], ledger: ledger, now: date(5, 20), calendar: calendar)
        #expect(first.map(\.source) == ["a", "b"])
        #expect(first.allSatisfy { $0.win == .plannedTask && $0.at == date(5, 20) })
        for win in first {
            ledger.entries.append(.earned(win.win, source: win.source, at: win.at, deviceID: "t"))
        }
        // Already earned ones don't count again; only one more fits today.
        let more = [done("a"), done("b"), done("c"), done("d")]
        let second = DailyAgenda.wins(in: more, ledger: ledger, now: date(5, 21), calendar: calendar)
        #expect(second.map(\.source) == ["c"])
        // A new hub day has room again.
        let tomorrow = DailyAgenda.wins(in: more, ledger: ledger, now: date(6, 9), calendar: calendar)
        #expect(tomorrow.map(\.source) == ["c", "d"])
    }

    @Test func unplannedOrUnfinishedTasksEarnNothing() {
        var onTheSpot = done("x")
        onTheSpot.planned = false
        var open = done("y")
        open.done = false
        let wins = DailyAgenda.wins(in: [onTheSpot, open], ledger: CanLedger(), now: date(5, 20), calendar: calendar)
        #expect(wins.isEmpty)
        #expect(Win.plannedTask.cans == 1)
    }
}
