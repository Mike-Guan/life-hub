import XCTest

// Used by scripts/check-card-shots.sh to record the "不对" card (Issue #236) for UI 审核, from a real long
// press on the character. Not part of CI's tests.
/// Opens the card with a long press on HAKU and closes it with a tap on the dim layer.
@MainActor
final class CheckCardRecording: XCTestCase {
    func testLongPressOpensTheCardAndATapClosesIt() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-screenshot-mode", "chill", "-screenshot-persona", "haku", "-screenshot-energy", "low",
            "-screenshot-check", "hold",
        ]
        app.launch()
        let answer = app.buttons["其实很累"]
        XCTAssertFalse(answer.exists)
        sleep(2)
        // The character fills the upper part of the screen.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.38)).press(forDuration: 1)
        // No queries while the card fades in: each one stalls the app, and the recording loses the fade.
        sleep(2)
        XCTAssertTrue(answer.exists)
        // The header, above the card, is covered by the dim layer.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        sleep(1)
        XCTAssertFalse(answer.exists)
    }
}
