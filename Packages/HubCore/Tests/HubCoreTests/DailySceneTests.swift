import Testing

@testable import HubCore

@Suite struct DailySceneTests {
    @Test func titlesPickTheirScene() {
        let titles: [String: DailyScene] = [
            "星巴克 拿铁": .coffee,
            "和同事聚餐": .meal,
            "Team MEETING": .meeting,
            "电话面试": .call,
            "スーパー": .grocery,
            "优衣库逛街": .shopping,
            "做饭": .cook,
            "剪头": .haircut,
            "歯医者": .doctor,
            "练腿": .gym,
            "晨跑 5km": .run,
            "散步晒太阳": .stroll,
            "约拍人像": .photo,
            "见朋友": .friends,
        ]
        for (title, scene) in titles {
            #expect(DailyScene(title: title) == scene, "\(title)")
        }
    }

    @Test func theFirstSceneInTheLibraryWins() {
        // Lunch comes before meet, and photo before friends.
        #expect(DailyScene(title: "lunch meet") == .meal)
        #expect(DailyScene(title: "约拍") == .photo)
    }

    @Test func shoppingForVegetablesIsAGroceryRun() {
        #expect(DailyScene(title: "购物 买衣服") == .shopping)
        #expect(DailyScene(title: "购物 菜和肉") == .grocery)
    }

    @Test func otherTitlesHaveNoScene() {
        #expect(DailyScene(title: "") == nil)
        #expect(DailyScene(title: "写周报") == nil)
    }
}
