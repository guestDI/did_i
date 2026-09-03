import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testFreshInstallCompletesTheThreeScreenFlow() throws {
        let app = freshApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["What did you last go back home to check?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["The stove"].exists)

        tap(app.buttons["The stove"], in: app)
        let practiceRow = confirmationRow(in: app)
        XCTAssertTrue(practiceRow.waitForExistence(timeout: 3))
        XCTAssertEqual(practiceRow.value as? String, "No record yet. Easy fix.")

        tap(practiceRow, in: app)
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 3))
        XCTAssertEqual(practiceRow.value as? String, "logged just now")

        tap(app.buttons["Done"], in: app)
        XCTAssertTrue(app.staticTexts["Put it where you'll look"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["View steps"].exists)
        XCTAssertTrue(app.buttons["Skip for now"].exists)

        tap(app.buttons["View steps"], in: app)
        XCTAssertTrue(
            app.staticTexts["Long-press an empty part of your home screen."]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["Search for \"Did I?\"."].exists)
        tap(app.buttons["Done"], in: app)
        XCTAssertTrue(app.buttons["Skip for now"].waitForExistence(timeout: 3))

        tap(app.buttons["Skip for now"], in: app)
        let boardRow = confirmationRow(in: app)
        XCTAssertTrue(boardRow.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Put it where you'll look"].exists)
    }

    @MainActor
    func testPracticeConfirmationSurvivesRelaunchBeforeDone() throws {
        let app = freshApp()
        app.launch()

        XCTAssertTrue(app.buttons["The stove"].waitForExistence(timeout: 5))
        tap(app.buttons["The stove"], in: app)

        let practiceRow = confirmationRow(in: app)
        XCTAssertTrue(practiceRow.waitForExistence(timeout: 3))
        tap(practiceRow, in: app)
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 3))

        app.terminate()
        app.launchArguments = localeArguments
        app.launch()

        let resumedRow = confirmationRow(in: app)
        XCTAssertTrue(resumedRow.waitForExistence(timeout: 5))
        XCTAssertEqual(resumedRow.value as? String, "logged just now")
        XCTAssertTrue(app.buttons["Done"].exists)
        XCTAssertFalse(app.buttons["The stove"].exists)
    }

    @MainActor
    func testClearedPracticeConfirmationStaysClearedAfterRelaunch() throws {
        let app = freshApp()
        app.launch()

        XCTAssertTrue(app.buttons["The stove"].waitForExistence(timeout: 5))
        tap(app.buttons["The stove"], in: app)

        let practiceRow = confirmationRow(in: app)
        XCTAssertTrue(practiceRow.waitForExistence(timeout: 3))
        tap(practiceRow, in: app)
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 3))

        tap(app.buttons["More actions"], in: app)
        XCTAssertTrue(app.buttons["Clear current confirmation"].waitForExistence(timeout: 2))
        tap(app.buttons["Clear current confirmation"], in: app)

        app.terminate()
        app.launchArguments = localeArguments
        app.launch()

        let resumedRow = confirmationRow(in: app)
        XCTAssertTrue(resumedRow.waitForExistence(timeout: 5))
        XCTAssertEqual(resumedRow.value as? String, "No record yet. Easy fix.")
        XCTAssertFalse(app.buttons["Done"].exists)
    }

    @MainActor
    private func freshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetStoreForUITesting"] + localeArguments
        return app
    }

    private var localeArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    @MainActor
    private func confirmationRow(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["confirmationRow.The stove"]
    }

    @MainActor
    private func tap(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        app.activate()
        XCTAssertTrue(element.waitForExistence(timeout: timeout), file: file, line: line)
        let hittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [hittable], timeout: timeout),
            .completed,
            file: file,
            line: line
        )
        element.tap()
    }
}
