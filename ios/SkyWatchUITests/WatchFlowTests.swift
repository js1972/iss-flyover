import XCTest

final class WatchFlowTests: XCTestCase {
    @MainActor private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--watch-preview"] + arguments; app.launch(); return app
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor private func assertPrimaryActionFits(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.isHittable, file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.minX, app.frame.minX, file: file, line: line)
        XCTAssertLessThanOrEqual(element.frame.maxX, app.frame.maxX, file: file, line: line)
        // Keep the complete action above the persistent page indicators.
        XCTAssertLessThanOrEqual(element.frame.maxY, app.frame.maxY - 8, file: file, line: line)
    }
    @MainActor func testTonightOpensObjectGuidanceAndReturns() {
        let app = launch()
        XCTAssertTrue(app.buttons["findIt"].waitForExistence(timeout: 15))
        assertPrimaryActionFits(app.buttons["findIt"], in: app)
        capture(app, "Watch Tonight")
        app.buttons["findIt"].tap()
        XCTAssertTrue(app.staticTexts["observationState"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Saturn"].exists)
        capture(app, "Watch Saturn guidance")
        app.buttons["watchBack"].firstMatch.tap()
        XCTAssertTrue(app.buttons["findIt"].waitForExistence(timeout: 5))
        app.swipeLeft()
        XCTAssertTrue(app.buttons["viewPath"].waitForExistence(timeout: 5))
        assertPrimaryActionFits(app.buttons["viewPath"], in: app)
        capture(app, "Watch Next ISS")
        app.buttons["viewPath"].tap()
        XCTAssertTrue(app.staticTexts["issElevation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["issElevation"].label.contains("preview"))
        capture(app, "Watch ISS preview")
    }
    @MainActor func testActivePass() {
        let app = launch(["--active-pass"])
        XCTAssertTrue(app.staticTexts["issElevation"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["issElevation"].label.contains("visible now"))
        capture(app, "Watch Active Pass")
    }
    @MainActor func testMoonPlacesAndLargeText() {
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let find = app.buttons["findIt"]
        XCTAssertTrue(find.waitForExistence(timeout: 15))
        // A full-screen flick can skip the action entirely at accessibility sizes.
        for _ in 0..<12 where !find.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)), withVelocity: .slow, thenHoldForDuration: 0.5)
        }
        XCTAssertTrue(find.isHittable)
        capture(app, "Watch largest text")
        find.tap()
        XCTAssertTrue(app.staticTexts["observationState"].waitForExistence(timeout: 5))
        app.buttons["watchBack"].firstMatch.tap()
        let moon = app.buttons["moonDetails"]
        for _ in 0..<8 where !moon.isHittable { app.swipeUp() }
        XCTAssertTrue(moon.isHittable); moon.tap()
        XCTAssertTrue(app.staticTexts["42% lit"].waitForExistence(timeout: 5))
        capture(app, "Watch Moon")
        let place = app.buttons["observingPlace"]
        for _ in 0..<8 where !place.isHittable { app.swipeUp() }
        XCTAssertTrue(place.isHittable); place.tap()
        XCTAssertTrue(app.buttons["Perth"].waitForExistence(timeout: 5))
    }
    @MainActor func testMissingAndExpiredForecast() {
        var app = launch(["--empty-watch"])
        XCTAssertTrue(app.buttons["requestForecast"].waitForExistence(timeout: 15))
        capture(app, "Watch first launch")
        app.terminate(); app = launch(["--expired-watch"])
        XCTAssertTrue(app.staticTexts["Forecast needs a refresh"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["findIt"].exists)
        capture(app, "Watch expired forecast")
    }
    @MainActor func testNoPassDiffersFromNoOrbit() {
        var app = launch(["--no-iss", "--iss-page"])
        XCTAssertTrue(app.staticTexts["No visible pass"].waitForExistence(timeout: 15))
        app.terminate(); app = launch(["--no-orbit", "--iss-page"])
        XCTAssertTrue(app.staticTexts["ISS data unavailable"].waitForExistence(timeout: 15))
        capture(app, "Watch missing orbit")
    }
}
