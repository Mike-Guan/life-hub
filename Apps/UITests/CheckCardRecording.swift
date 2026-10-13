import XCTest

// Used by scripts/check-card-shots.sh to record the "不对" card (Issue #236) for UI 审核, from a real tap
// on 不对？ under the character. Not part of CI's tests.
/// Opens the card from 不对？ and closes it with a tap on the dim layer.
@MainActor
final class CheckCardRecording: XCTestCase {
    func testCheckButtonOpensTheCardAndATapClosesIt() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-screenshot-mode", "chill", "-screenshot-persona", "haku", "-screenshot-energy", "low",
            "-screenshot-check", "hold",
        ]
        app.launch()
        let answer = app.buttons["其实很累"]
        XCTAssertFalse(answer.exists)
        sleep(2)
        // UI 审核 2026-10-13: the whole energy row is the tap target, at least 44 pt tall.
        XCTAssertGreaterThanOrEqual(app.buttons["不对？"].frame.height, 44)
        app.buttons["不对？"].tap()
        // No queries while the card fades in: each one stalls the app, and the recording loses the fade.
        sleep(2)
        XCTAssertTrue(answer.exists)
        // The header, above the card, is covered by the dim layer.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        sleep(1)
        XCTAssertFalse(answer.exists)
    }
}
