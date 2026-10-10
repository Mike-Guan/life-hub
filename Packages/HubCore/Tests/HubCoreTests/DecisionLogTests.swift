import Foundation
import Testing

@testable import HubCore

@Suite struct DecisionLogTests {
    let start = Date(timeIntervalSince1970: 1_790_000_000)

    func decision(
        _ action: String,
        kind: Decision.Kind = .push,
        for subject: String = "invite",
        at offset: TimeInterval = 0,
        target: Date? = nil
    ) -> Decision {
        Decision(
            kind: kind,
            action: action,
            target: target,
            signals: [DecisionLog.subjectKey: subject],
            at: start.addingTimeInterval(offset),
            deviceID: "test"
        )
    }

    func roundTrip(_ log: DecisionLog) throws -> DecisionLog {
        let data = try HubJSON.encoder().encode(log)
        return try HubJSON.decoder().decode(DecisionLog.self, from: data)
    }

    @Test func roundTripKeepsEveryField() throws {
        var first = decision("couchScroll", target: start.addingTimeInterval(600))
        first.outcome = .yes
        first.feedback = .confirmed
        let log = DecisionLog(decisions: [first])
        #expect(try roundTrip(log) == log)
    }

    @Test func missingFieldsGetDefaults() throws {
        let json = """
            {"decisions": [{"id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "kind": "line",
              "at": "2026-10-10T05:00:00Z", "action": "none", "outcome": "laterKind"}]}
            """
        let log = try HubJSON.decoder().decode(DecisionLog.self, from: Data(json.utf8))
        let only = try #require(log.decisions.first)
        #expect(log.schemaVersion == 1)
        #expect(only.signals.isEmpty)
        #expect(only.outcome == nil)
        #expect(only.updatedBy == "unknown")
        #expect(only.createdAt == only.at)
    }

    @Test func unreadableRecordsAreKeptAndWrittenBack() throws {
        let json = """
            {"schemaVersion": 1, "decisions": [
              {"id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "kind": "push", "at": "2026-10-10T05:00:00Z",
               "action": "none"},
              {"id": "7F9619FF-8B86-D011-B42D-00C04FC964FF", "kind": "hug", "at": "2026-10-10T05:00:00Z",
               "action": "none"}]}
            """
        let log = try HubJSON.decoder().decode(DecisionLog.self, from: Data(json.utf8))
        #expect(log.decisions.count == 1)
        #expect(log.unreadable.count == 1)
        let again = try roundTrip(log)
        #expect(again.unreadable == log.unreadable)
    }

    @Test func trimDropsOnlyOldDecisions() {
        var log = DecisionLog(decisions: [decision("old", at: 0), decision("new", at: 80 * 86_400)])
        log.trim(now: start.addingTimeInterval(91 * 86_400))
        #expect(log.decisions.map(\.action) == ["new"])
    }

    @Test func judgeAppliesOnce() {
        let first = decision("couchScroll")
        var log = DecisionLog(decisions: [first])
        let judged = log.judge(first.id, .no, by: "test", at: start)
        let again = log.judge(first.id, .yes, by: "test", at: start)
        let missing = log.judge(UUID(), .yes, by: "test", at: start)
        #expect(judged && !again && !missing)
        #expect(log.decisions.first?.outcome == .no)
    }

    @Test func appendIfChangedSkipsTheSamePlan() {
        let at = start.addingTimeInterval(3600)
        var log = DecisionLog()
        let added = [
            log.appendIfChanged(decision("couchScroll", target: at)),
            log.appendIfChanged(decision("couchScroll", at: 60, target: at)),
            // Another subject is judged on its own.
            log.appendIfChanged(decision("offWork", for: "offWork", target: at)),
            log.appendIfChanged(decision(Decision.noAction, at: 120)),
        ]
        #expect(added == [true, false, true, true])
        #expect(log.decisions.map(\.action) == ["couchScroll", "offWork", Decision.noAction])
    }

    @Test func latestMatchesActionAndTarget() {
        let at = start.addingTimeInterval(3600)
        let sent = decision("couchScroll", target: at)
        let log = DecisionLog(decisions: [sent, decision(Decision.noAction, at: 60)])
        #expect(log.latest(.push, action: "couchScroll", target: at)?.id == sent.id)
        #expect(log.latest(.push)?.action == Decision.noAction)
        #expect(log.latest(.line) == nil)
    }

    @Test func updateWritesOnlyWhenChanged() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "decision-log.json")
        #expect(DecisionLog.update(at: url, now: start) { _ in false } == nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        let first = decision("couchScroll")
        #expect(DecisionLog.update(at: url, now: start) { $0.appendIfChanged(first) } == nil)
        #expect(DecisionLog.update(at: url, now: start) { $0.appendIfChanged(first) } == nil)
        #expect(DecisionLog.read(from: url).decisions == [first])
    }

    @Test func textListsActionSignalsAndOutcome() {
        var first = decision("couchScroll")
        first.signals["hour"] = "21"
        first.outcome = .no
        let text = DecisionLog(decisions: [first]).text(in: TimeZone(identifier: "UTC")!)
        #expect(text.contains("[push] couchScroll"))
        #expect(text.contains("for=invite hour=21"))
        #expect(text.contains("结果=no"))
    }
}
