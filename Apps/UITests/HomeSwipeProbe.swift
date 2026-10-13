import XCTest

// Throwaway probe: does the home page scroll sideways?
@MainActor
final class HomeSwipeProbe: XCTestCase {
    func shoot(_ name: String) {
        let out = ProcessInfo.processInfo.environment["PROBE_OUT"] ?? NSTemporaryDirectory()
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: out).appendingPathComponent("\(name).png"))
    }

    func run(_ name: String, _ arguments: [String]) {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        sleep(6)
        shoot("\(name)-0")
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.62))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.62))
        start.press(forDuration: 0.05, thenDragTo: end)
        sleep(2)
        shoot("\(name)-1")
        app.terminate()
    }

    func testSwipe() {
        run("chill", ["-screenshot-mode", "chill", "-screenshot-persona", "haku", "-screenshot-energy", "low"])
        run("work", ["-screenshot-mode", "work", "-screenshot-persona", "haku"])
        run("plain", [])
    }
}
