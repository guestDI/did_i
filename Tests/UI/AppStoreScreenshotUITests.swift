import XCTest

final class AppStoreScreenshotUITests: XCTestCase {
    @MainActor
    func testCaptureEnglishAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetStoreForUITesting",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["The stove"].waitForExistence(timeout: 5))
        capture("01-choose-what-matters")

        app.buttons["The stove"].tap()
        let practiceRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Confirm The stove")
        ).firstMatch
        XCTAssertTrue(practiceRow.waitForExistence(timeout: 3))
        practiceRow.tap()
        capture("02-one-tap-confirmation")

        app.terminate()
        app.launchArguments = [
            "-appStoreScreenshotBoard",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()

        let boardRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Confirm The stove")
        ).firstMatch
        XCTAssertTrue(boardRow.waitForExistence(timeout: 5))
        capture("03-current-at-a-glance")

        app.buttons["More actions"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Edit item"].waitForExistence(timeout: 2))
        app.buttons["Edit item"].tap()
        XCTAssertTrue(app.buttons["How long a tick lasts"].waitForExistence(timeout: 3))
        app.buttons["How long a tick lasts"].tap()
        XCTAssertTrue(app.navigationBars["How long a tick lasts"].waitForExistence(timeout: 3))
        capture("04-expiry-you-control")

        app.buttons["Cancel"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        capture("05-private-by-design")
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
