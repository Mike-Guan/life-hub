import Testing

@testable import CompanionKit

@Suite struct KuroRoomArtTests {
    @Test func herRoomItemsComeFromHerShopIds() {
        #expect(KuroRoomItem(shopID: "kuro.room.poster.cat") == .posterCat)
        #expect(KuroRoomItem(shopID: "kuro.room.mug.strawberry") == .mugStrawberry)
        #expect(KuroRoomItem(shopID: "room.bench") == nil)
        #expect(KuroRoomItem(shopID: "kuro.room.flower") == nil)
    }

    @Test func everyRoomItemFillsABoxAboveTheFloor() {
        for item in KuroRoomItem.allCases {
            let boxes = KuroRoomArt.boxes(item, at: GridPoint(x: 2, y: 8))
            #expect(!boxes.isEmpty && boxes.allSatisfy { $0.z1 > $0.z0 }, "\(item)")
        }
    }
}
