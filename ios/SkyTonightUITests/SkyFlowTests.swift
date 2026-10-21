import XCTest
import UIKit
final class SkyFlowTests: XCTestCase {
    @MainActor private func selectTab(_ name: String, in app: XCUIApplication) {
        // iPad's floating tab strip exposes cells; iPhone exposes tab-bar buttons.
        let tab = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", name)).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 5)); tab.tap()
    }
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
        selectTab("Upcoming", in: app)
        XCTAssertTrue(app.navigationBars["Next 7 nights"].waitForExistence(timeout:5))
        app.buttons["ISS passes"].tap()
        XCTAssertTrue(app.staticTexts["ISS data unavailable. Refresh to try again."].firstMatch.waitForExistence(timeout:5))
        selectTab("Settings", in: app)
        XCTAssertTrue(app.textFields["placeName"].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["Use my location"].exists)
    }
}

extension SkyFlowTests {
    @MainActor func testLargeTextPreviewAndSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let preview = app.buttons["tonightPreview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 15))
        for _ in 0..<4 where !preview.isHittable { app.swipeUp() }
        XCTAssertTrue(preview.isHittable)
        capture(app, "Largest accessibility text - Tonight")
        preview.tap()
        let live = app.buttons["returnLive"]
        XCTAssertTrue(live.waitForExistence(timeout: 10))
        for _ in 0..<5 where !live.isHittable { app.swipeUp() }
        XCTAssertTrue(live.isHittable)
        capture(app, "Largest accessibility text - Sky controls")
        selectTab("Settings", in: app)
        XCTAssertTrue(app.buttons["Use my location"].waitForExistence(timeout: 5))
    }
    @MainActor func testLiveAppleWeatherOptIn() throws {
        guard ProcessInfo.processInfo.environment["SKY_WEATHER_LIVE_CHECK"] == "YES" else { throw XCTSkip("Opt-in integration check; normal tests remain offline") }
        let app = XCUIApplication(); app.launch()
        selectTab("Settings", in: app)
        let toggle = app.switches["appleWeatherToggle"]
        for _ in 0..<5 where !toggle.isHittable { app.swipeUp() }
        XCTAssertTrue(toggle.isHittable)
        if toggle.value as? String == "0" {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
        XCTAssertEqual(toggle.value as? String, "1", "The weather opt-in must be enabled before making a live request")
        capture(app, "Weather opt-in state")
        guard toggle.value as? String == "1" else { return }
        selectTab("Tonight", in: app)
        let credit = app.descendants(matching: .any).matching(identifier: "appleWeatherCredit").firstMatch
        XCTAssertTrue(credit.waitForExistence(timeout: 60), "Live WeatherKit should provide attributed conditions for the simulator's default Perth location")
        capture(app, "Live Apple Weather with official attribution")
        selectTab("Settings", in: app)
        for _ in 0..<5 where !toggle.isHittable { app.swipeUp() }
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "0")
        selectTab("Tonight", in: app)
        XCTAssertFalse(credit.exists, "Opting out removes cached weather and its attribution from the app")
        XCTAssertTrue(app.buttons["enableWeatherSettings"].exists)
    }
    @MainActor func testIPadRotationsAndPrivacy() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad layout checks run on an iPad simulator") }
        let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft, .portraitUpsideDown] {
            XCUIDevice.shared.orientation = orientation
            selectTab("Tonight", in: app)
            let preview = app.buttons["tonightPreview"]
            XCTAssertTrue(preview.waitForExistence(timeout: 15)); XCTAssertTrue(preview.isHittable)
            capture(app, "iPad Tonight - \(orientation.rawValue)")
            preview.tap()
            XCTAssertTrue(app.buttons["returnLive"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.sliders["skyTimeSlider"].isHittable)
            capture(app, "iPad Sky preview - \(orientation.rawValue)")
            selectTab("Upcoming", in: app)
            XCTAssertTrue(app.navigationBars["Next 7 nights"].waitForExistence(timeout: 5))
            capture(app, "iPad Upcoming - \(orientation.rawValue)")
        }
        selectTab("Settings", in: app)
        for _ in 0..<5 where !app.buttons["Privacy policy"].isHittable { app.swipeUp() }
        app.buttons["Privacy policy"].tap()
        XCTAssertTrue(app.staticTexts["About this policy"].waitForExistence(timeout: 5))
        capture(app, "iPad offline privacy policy")
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testWidgetLayouts() throws {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--widget-preview"]; app.launch()
        XCTAssertTrue(app.staticTexts["Widget previews"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["SKY TONIGHT"].firstMatch.waitForExistence(timeout: 15))
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Widget layouts - light appearance"; image.lifetime = .keepAlways; add(image)
        XCTAssertTrue(app.staticTexts["ISS data unavailable"].exists)
        app.buttons["Dark"].tap()
        let darkImage = XCTAttachment(screenshot: app.screenshot()); darkImage.name = "Widget layouts - dark appearance"; darkImage.lifetime = .keepAlways; add(darkImage)
    }
}
