import Foundation
import Testing

@testable import HubCore

@MainActor
@Suite struct HomeSceneTests {
    let at = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func walkingFromTheOfficeLastsHalfAnHour() {
        let store = ModeStore(fileURL: nil, deviceID: "test")
        store.switchTo(.work, source: .location, at: at)
        var presence = PlacePresence()
        presence.record(.office, entered: true, at: at)
        presence.record(.office, entered: false, at: at + 8 * 3600)
        let inputs = HomeSceneInputs(log: store.log, signals: ActivitySignals(presence: presence))
        let left = at + 8 * 3600
        #expect(inputs.scene(at: left + 60).walking == .office)
        #expect(inputs.scene(at: left + PlaceWalk.lasts + 60).walking == nil)
        let scenes = inputs.timeline(from: left, hours: 1)
        #expect(scenes.scene(at: left + 10 * 60)?.walking == .office)
        #expect(scenes.scene(at: left + 45 * 60)?.walking == nil)
    }

    @Test func timelineKeepsOnlyChangesAndStartsAtNow() {
        let store = ModeStore(fileURL: nil, deviceID: "test")
        store.switchTo(.money, at: at)
        let inputs = HomeSceneInputs(log: store.log)
        let scenes = inputs.timeline(from: at, hours: 2)
        #expect(scenes.map(\.scene.codingCans) == [0, 1, 2, 3])
        #expect(scenes.first?.from == at)
        #expect(scenes.allSatisfy { $0.scene.moment == .vibeCoding })
        #expect(scenes.scene(at: at - 60) == nil)
        #expect(scenes.scene(at: at + 45 * 60)?.codingCans == 1)
        #expect(scenes.scene(at: at + 5 * 3600)?.codingCans == 3)
    }

    @Test func scenesTravelToTheWatchAndOldPayloadsHaveNone() throws {
        let snapshot = WidgetSnapshot(mode: .money, since: at, updatedAt: at)
        let scene = HomeScene(activity: .runDay, moment: .vibeCoding, walking: .home, bath: true, codingCans: 2)
        let payload = WatchPayload(snapshot: snapshot, scenes: [TimedScene(from: at, scene: scene)])
        let message = try #require(payload.message)
        #expect(WatchPayload(message: message) == payload)

        let old = WatchPayload(snapshot: snapshot)
        let data = try HubJSON.encoder().encode(old)
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["scenes"] = nil
        let oldData = try JSONSerialization.data(withJSONObject: json)
        #expect(try HubJSON.decoder().decode(WatchPayload.self, from: oldData).scenes.isEmpty)
    }

    @Test func anUnknownSceneValueFallsBackToNothing() throws {
        let data = Data(#"{"activity":"skydiving","moment":"vibeCoding","bath":true}"#.utf8)
        let scene = try HubJSON.decoder().decode(HomeScene.self, from: data)
        #expect(scene == HomeScene(moment: .vibeCoding, bath: true))
    }

    @Test func scenesDontChangeTheWatchFace() {
        let snapshot = WidgetSnapshot(mode: .money, since: at, updatedAt: at)
        let plain = WatchPayload(snapshot: snapshot)
        let playing = WatchPayload(snapshot: snapshot, scenes: [TimedScene(from: at, scene: HomeScene(codingCans: 1))])
        #expect(plain.drawsLike(playing))
    }
}
