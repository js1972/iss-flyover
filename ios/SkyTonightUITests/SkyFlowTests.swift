import XCTest
final class SkyFlowTests: XCTestCase {
    @MainActor func testTonightPreviewUpcomingAndSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        let preview = app.buttons["tonightPreview"]
        XCTAssertTrue(preview.waitForExistence(timeout:30))
        let home = XCTAttachment(screenshot:app.screenshot()); home.name="Tonight"; home.lifetime = .keepAlways; add(home)
        preview.tap()
        XCTAssertTrue(app.buttons["returnLive"].waitForExistence(timeout:10))
        let sky = XCTAttachment(screenshot:app.screenshot()); sky.name="Sky preview"; sky.lifetime = .keepAlways; add(sky)
        app.buttons["returnLive"].tap()
        XCTAssertFalse(app.buttons["returnLive"].exists)
        app.tabBars.buttons["Upcoming"].tap()
        XCTAssertTrue(app.navigationBars["Next 7 nights"].waitForExistence(timeout:5))
        app.buttons["ISS passes"].tap()
        XCTAssertTrue(app.staticTexts["ISS data unavailable. Refresh to try again."].firstMatch.waitForExistence(timeout:5))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.textFields["placeName"].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["Use my location"].exists)
    }
}

extension SkyFlowTests {
    @MainActor func testWidgetLayouts() throws {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--widget-preview"]; app.launch()
        XCTAssertTrue(app.staticTexts["Widget previews"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["SKY TONIGHT"].firstMatch.waitForExistence(timeout: 15))
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Widget layouts"; image.lifetime = .keepAlways; add(image)
        XCTAssertTrue(app.staticTexts["ISS data unavailable"].exists)
    }
}
