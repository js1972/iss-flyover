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
        // Keep the complete action clear of the rounded bottom edge.
        XCTAssertLessThanOrEqual(element.frame.maxY, app.frame.maxY - 8, file: file, line: line)
    }
    @MainActor func testTonightOpensObjectGuidanceAndReturns() {
        let app = launch()
        XCTAssertTrue(app.buttons["findIt"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Find it"].exists, "The artwork itself opens guidance; no separate Find it button")
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
        let remaining = app.staticTexts["issRemaining"]
        XCTAssertTrue(remaining.isHittable)
        XCTAssertLessThanOrEqual(remaining.frame.maxY, app.frame.maxY - 8)
        capture(app, "Watch Active Pass")
    }
    @MainActor func testMoonPlacesAndLargeText() {
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let find = app.buttons["findIt"]
        XCTAssertTrue(find.waitForExistence(timeout: 15))
        // At large text sizes the entire target area may extend below the fold,
        // but its visible artwork/title must still be tappable without scrolling.
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
    @MainActor func testRepeatedPagingScrollingAndResumeDuringForecastUpdates() {
        let app = launch(["--stress-sync"])
        XCTAssertTrue(app.buttons["findIt"].waitForExistence(timeout: 15))
        var lastRevision = 1
        for cycle in 0..<8 {
            app.swipeLeft()
            XCTAssertTrue(app.buttons["viewPath"].waitForExistence(timeout: 4), "Left swipe cycle \(cycle)")
            XCTAssertTrue(app.buttons["viewPath"].isHittable)
            app.buttons["viewPath"].tap()
            XCTAssertTrue(app.staticTexts["issElevation"].waitForExistence(timeout: 4))
            app.swipeUp()
            let reminder = app.buttons["watchReminder"]
            for _ in 0..<3 where !reminder.isHittable { app.swipeUp() }
            XCTAssertTrue(reminder.isHittable)
            XCTAssertFalse(app.buttons["continueOnPhone"].exists)
            if cycle == 0 { capture(app, "Watch preview footer") }
            app.buttons["watchBack"].firstMatch.tap()
            XCTAssertTrue(app.buttons["viewPath"].waitForExistence(timeout: 4))
            app.swipeRight()
            XCTAssertTrue(app.buttons["findIt"].waitForExistence(timeout: 4), "Right swipe cycle \(cycle)")
            app.swipeUp()
            let sync = app.staticTexts["stressSync"]
            XCTAssertTrue(sync.waitForExistence(timeout: 4))
            let revision = Int(sync.label.split(separator: " ").last ?? "0") ?? 0
            XCTAssertGreaterThan(revision, lastRevision, "Forecast processing must continue during interaction")
            lastRevision = revision
            for _ in 0..<4 where !app.buttons["findIt"].isHittable { app.swipeDown() }
            XCTAssertTrue(app.buttons["findIt"].isHittable)
            app.buttons["findIt"].tap()
            XCTAssertTrue(app.staticTexts["observationState"].waitForExistence(timeout: 4))
            app.buttons["watchBack"].firstMatch.tap()
            if cycle == 3 {
                XCUIDevice.shared.press(.home)
                app.activate()
                XCTAssertTrue(app.buttons["findIt"].waitForExistence(timeout: 5))
            }
        }
        capture(app, "Watch after paging and sync stress")
    }
    @MainActor private func checkEventCards(largeText: Bool) {
        let textArguments = largeText ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : []
        let app = launch(["--event-cards"] + textArguments)
        XCTAssertTrue(app.buttons["findIt"].waitForExistence(timeout: 15))
        for index in 0..<3 {
            let id = "demo-card-\(index)"
            let card = app.buttons["eventCard-\(id)"]
            for _ in 0..<18 {
                if card.isHittable && card.frame.minY >= 40 && card.frame.maxY <= app.frame.maxY - 8 { break }
                let tooHigh = card.isHittable && card.frame.minY < 40
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: tooHigh ? 0.42 : 0.76))
                    .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: tooHigh ? 0.55 : 0.53)),
                           withVelocity: .slow, thenHoldForDuration: 0.3)
            }
            assertPrimaryActionFits(card, in: app)
            XCTAssertGreaterThanOrEqual(card.frame.minY, 40)
            let title = app.staticTexts["eventTitle-\(id)"]
            let detail = app.staticTexts["eventDetail-\(id)"]
            XCTAssertEqual(title.label, ["Small Magellanic Cloud", "Large Magellanic Cloud", "Orion Nebula"][index])
            for text in [title, detail] {
                XCTAssertGreaterThanOrEqual(text.frame.minX, card.frame.minX + 10)
                XCTAssertLessThanOrEqual(text.frame.maxX, card.frame.maxX - 10)
                XCTAssertGreaterThanOrEqual(text.frame.minY, card.frame.minY + 10)
                XCTAssertLessThanOrEqual(text.frame.maxY, card.frame.maxY - 10)
            }
            XCTAssertLessThanOrEqual(title.frame.maxY + 6, detail.frame.minY)
            capture(app, "Event card \(index) \(largeText ? "large text" : "default")")
            card.tap()
            XCTAssertTrue(app.staticTexts["observationState"].waitForExistence(timeout: 4))
            app.buttons["watchBack"].firstMatch.tap()
            XCTAssertTrue(card.waitForExistence(timeout: 4))
        }
        app.swipeLeft()
        XCTAssertTrue(app.buttons["viewPath"].waitForExistence(timeout: 4))
        app.swipeRight()
        XCTAssertTrue(app.buttons["eventCard-demo-card-2"].waitForExistence(timeout: 4))
    }
    @MainActor func testEventCardsFitAndOpenDetails() { checkEventCards(largeText: false) }
    @MainActor func testEventCardsAtLargestText() { checkEventCards(largeText: true) }
}
