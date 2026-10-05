import Foundation
import Testing

@testable import HubCore

@Suite struct DailyCueTests {
    @Test func aCueKeepsItsStagePropAndId() {
        let cue = DailyCue(stage: .now, prop: .gymBag, id: "task-1:2026-10-05")
        #expect(cue.stage == .now && cue.prop == .gymBag && cue.id == "task-1:2026-10-05")
        #expect(cue != DailyCue(stage: .soon, prop: .gymBag, id: "task-1:2026-10-05"))
        #expect(DailyProp.allCases.map(\.rawValue) == ["headphones", "bag", "gymBag", "note"])
        #expect(CompanionEvent.taskDone(id: "a", focus: true) != .taskDone(id: "a", focus: false))
    }
}
