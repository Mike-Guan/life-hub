import Foundation
import Testing

@testable import HubCore

@MainActor
@Suite struct EnergyCheckTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    func temporaryLog() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)/decision-log.json")
    }

    @Test func answersMapToLevels() {
        #expect(EnergyCheck.level(after: .actuallyTired, guess: .low) == nil)
        #expect(EnergyCheck.level(after: .lessTired, guess: .low) == .okay)
        #expect(EnergyCheck.level(after: .lessTired, guess: .okay) == nil)
        #expect(EnergyCheck.level(after: .actuallyTired, guess: .okay) == .low)
        // At full energy both answers lower it.
        #expect(EnergyCheck.level(after: .lessTired, guess: .full) == .okay)
        #expect(EnergyCheck.level(after: .actuallyTired, guess: .full) == .low)
    }

    @Test func correctionWinsForTheRestOfTheDayOnly() throws {
        let energy = EnergyStore(fileURL: nil, deviceID: "test")
        energy.record(.sleep(minutes: 5 * 60, endedAt: date(3, 7), deviceID: "test"))
        let guess = try #require(energy.reading(now: date(3, 12), calendar: calendar))
        #expect(guess.level == .low)

        let url = temporaryLog()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let result = EnergyCheck.answer(.lessTired, to: guess, energy: energy, decisionLogURL: url, at: date(3, 12))
        #expect(result.error == nil)
        #expect(energy.reading(now: date(3, 22), calendar: calendar)?.level == .okay)

        energy.record(.sleep(minutes: 5 * 60, endedAt: date(4, 7), deviceID: "test"))
        #expect(energy.reading(now: date(4, 12), calendar: calendar)?.level == .low)

        let log = DecisionLog.read(from: url)
        let only = try #require(log.decisions.first)
        #expect(log.decisions.count == 1)
        #expect(only.id == result.report?.id)
        #expect(only.kind == .guess)
        #expect(only.action == "low")
        #expect(only.feedback == .corrected)
        #expect(only.signals["set"] == "okay")
        #expect(only.signals["source"] == "sleep")
    }

    @Test func agreeingAnswerWritesOnlyAConfirmedRecord() throws {
        let energy = EnergyStore(fileURL: nil, deviceID: "test")
        energy.record(.sleep(minutes: 5 * 60, endedAt: date(3, 7), deviceID: "test"))
        let guess = try #require(energy.reading(now: date(3, 12), calendar: calendar))
        let url = temporaryLog()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let result = EnergyCheck.answer(.actuallyTired, to: guess, energy: energy, decisionLogURL: url, at: date(3, 12))
        #expect(result.report == nil)
        #expect(energy.log.events.count == 1)
        let log = DecisionLog.read(from: url)
        #expect(log.decisions.map(\.feedback) == [.confirmed])
        #expect(log.decisions.first?.signals["set"] == Decision.noAction)
    }

    @Test func recordIsAppliedOnceByID() {
        let reading = EnergyReading(level: .full, reasons: [], source: .sleep)
        let report = EnergyEvent.selfReport(.low, at: date(3, 12), deviceID: "test")
        let record = EnergyCheck.decision(
            guess: reading,
            answer: .actuallyTired,
            report: report,
            at: date(3, 12),
            deviceID: "test"
        )
        var log = DecisionLog()
        let added = [log.appendOnce(record), log.appendOnce(record)]
        #expect(added == [true, false])
        #expect(log.decisions.count == 1)
    }

    @Test func linesFollowThePersona() {
        #expect(EnergyCheck.question(for: .low, persona: .haku) == "我觉得你今天没睡够。")
        #expect(EnergyCheck.question(for: .full, persona: .haku) == "我觉得你今天还行。")
        #expect(EnergyCheck.question(for: .low, persona: .kuro) == "……今天好像没睡够。")
        #expect(EnergyCheck.question(for: .okay, persona: .kuro) == "……今天还可以吧。")
        #expect(EnergyCheck.reply(corrected: true, persona: .haku) == "哦。")
        #expect(EnergyCheck.reply(corrected: false, persona: .haku) == "嗯。")
        #expect(EnergyCheck.reply(corrected: true, persona: .kuro) == "……嗯。")
        #expect(EnergyAnswer.allCases.map(\.title) == ["没那么累", "其实很累"])
    }
}
