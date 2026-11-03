import XCTest

final class WatchFlowTests: XCTestCase {
    @MainActor private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--watch-preview"] + arguments; app.launch(); return app
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor func testTonightOpensObjectGuidanceAndReturns() {
        let app = launch()
        XCTAssertTrue(app.buttons["findIt"].waitForExistence(timeout: 15))
        capture(app, "Watch Tonight")
        app.buttons["findIt"].tap()
        XCTAssertTrue(app.staticTexts["observationState"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Saturn"].exists)
        capture(app, "Watch Saturn guidance")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["findIt"].waitForExistence(timeout: 5))
        app.swipeLeft()
        XCTAssertTrue(app.buttons["viewPath"].waitForExistence(timeout: 5))
        capture(app, "Watch Next ISS")
        app.buttons["viewPath"].tap()
        XCTAssertTrue(app.staticTexts["observationState"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["observationState"].label.contains("PREVIEW"))
        capture(app, "Watch ISS preview")
    }
    @MainActor func testActivePass() {
        let app = launch(["--active-pass"])
        XCTAssertTrue(app.staticTexts["VISIBLE NOW"].waitForExistence(timeout: 15))
        capture(app, "Watch Active Pass")
    }
    @MainActor func testMoonPlacesAndLargeText() {
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let find = app.buttons["findIt"]
        XCTAssertTrue(find.waitForExistence(timeout: 15))
        for _ in 0..<5 where !find.isHittable { app.swipeUp() }
        XCTAssertTrue(find.isHittable)
        capture(app, "Watch largest text")
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
