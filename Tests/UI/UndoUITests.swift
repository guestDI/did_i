import XCTest

final class ClearConfirmationUITests: XCTestCase {
    @MainActor
    func testMoreMenuClearsRepeatedConfirmationsInOneAction() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-resetStoreForUITesting",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()

        app.buttons["The stove"].tap()

        let practiceRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Confirm The stove")
        ).firstMatch
        XCTAssertTrue(practiceRow.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["More actions"].waitForExistence(timeout: 2))
        practiceRow.tap()

        app.buttons["More actions"].tap()
        let firstClear = app.buttons["Clear current confirmation"]
        XCTAssertTrue(firstClear.waitForExistence(timeout: 2))
        firstClear.tap()
        let noPracticeRecord = NSPredicate(format: "value == %@", "No record yet. Easy fix.")
        expectation(for: noPracticeRecord, evaluatedWith: practiceRow)
        waitForExpectations(timeout: 3)

        practiceRow.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 2))
        done.tap()

        let skip = app.buttons["Skip for now"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()

        let boardRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Confirm The stove")
        ).firstMatch
        XCTAssertTrue(boardRow.waitForExistence(timeout: 3))
        XCTAssertNotEqual(boardRow.value as? String, "No current record.")

        // A second confirmation reproduces the reported case. Clearing the
        // visible status must work once, regardless of how many taps preceded it.
        boardRow.tap()
        app.buttons["More actions"].tap()
        let clear = app.buttons["Clear current confirmation"]
        XCTAssertTrue(clear.waitForExistence(timeout: 2))
        clear.tap()

        let unknown = NSPredicate(format: "value == %@", "No current record.")
        expectation(for: unknown, evaluatedWith: boardRow)
        waitForExpectations(timeout: 3)
    }
}
