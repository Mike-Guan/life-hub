import Foundation
import Testing

@testable import HubCore

@Suite struct WatchPayloadTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    func payload(line: String? = "上班中", energy: EnergyLevel? = .okay) -> WatchPayload {
        let snapshot = WidgetSnapshot(
            mode: .work,
            since: date(7, 9),
            energy: energy,
            line: line,
            updatedAt: date(7, 10)
        )
        return WatchPayload(snapshot: snapshot, wardrobe: Wardrobe(equipped: [.gloves: "gloves.gold"]))
    }

    @Test func travelsThroughAMessage() throws {
        let message = try #require(payload().message)
        #expect(WatchPayload(message: message) == payload())
    }

    @Test func ignoresAnEmptyOrUnreadableMessage() {
        #expect(WatchPayload(message: [:]) == nil)
        #expect(WatchPayload(message: [WatchPayload.messageKey: Data("{}".utf8)]) == nil)
        #expect(WatchPayload(message: [WatchPayload.messageKey: "text"]) == nil)
    }

    @Test func missingWardrobeAndBedtimeUseDefaults() throws {
        let snapshot = try HubJSON.encoder().encode(payload().snapshot)
        let json = #"{"snapshot":"# + String(decoding: snapshot, as: UTF8.self) + "}"
        let decoded = try HubJSON.decoder().decode(WatchPayload.self, from: Data(json.utf8))
        #expect(decoded.wardrobe == Wardrobe())
        #expect(decoded.bedtime == .standard)
        #expect(decoded.snapshot == payload().snapshot)
    }

    @Test func readsBackWhatItWrote() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "watch-\(UUID().uuidString)/watch-payload.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        #expect(WatchPayload.read(from: url) == nil)
        #expect(WatchPayload.read(from: nil) == nil)
        try payload().write(to: url)
        #expect(WatchPayload.read(from: url) == payload())
    }

    @Test func lineIsBedtimeThenTheAppsLineThenEnergy() {
        #expect(payload().line(at: date(7, 12), calendar: calendar) == "上班中")
        #expect(payload(line: nil).line(at: date(7, 12), calendar: calendar) == "电量\(EnergyLevel.okay.title)")
        #expect(payload(line: nil, energy: nil).line(at: date(7, 12), calendar: calendar) == "电量未知")
        let bedtime = HakuLines.line(.bedtime, at: date(7, 23, 45), calendar: calendar)
        #expect(payload().line(at: date(7, 23, 45), calendar: calendar) == bedtime)
    }

    @Test func redrawsWhenTheIPhoneWidgetsDo() {
        let now = date(7, 12)
        let expected = WidgetSnapshot.timelineDates(
            after: now,
            bedtime: .standard,
            needTimes: payload().snapshot.needTimes,
            calendar: calendar
        )
        #expect(payload().timelineDates(after: now, calendar: calendar) == expected)
    }
}
