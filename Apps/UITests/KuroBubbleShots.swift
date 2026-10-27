import XCTest

// SCRATCH ONLY: opens 家 from the house button so the script can screenshot it.
@MainActor
final class KuroBubbleShots: XCTestCase {
    func testOpenHome() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-screenshot-mode", "chill", "-screenshot-persona", "kuro", "-screenshot-energy", "low",
            "-screenshot-thought",
        ]
        app.launch()
        sleep(3)
        app.buttons["家"].firstMatch.tap()
        sleep(20)
    }
}
