import XCTest

final class UndoUITests: XCTestCase {
    @MainActor
    func testMoreMenuUndoExplainsAPreviousRecordThenClearsIt() throws {
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
        practiceRow.tap()

        let later = app.buttons["Later"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()

        let noThanks = app.buttons["No thanks"]
        XCTAssertTrue(noThanks.waitForExistence(timeout: 2))
        noThanks.tap()

        let boardRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Confirm The stove")
        ).firstMatch
        XCTAssertTrue(boardRow.waitForExistence(timeout: 3))
        XCTAssertNotEqual(boardRow.value as? String, "No record yet. Easy fix.")

        // A second confirmation reproduces the reported case: undoing it leaves
        // the first green record in place, which used to look like a dead button.
        boardRow.tap()
        app.buttons["More actions"].tap()
        let undo = app.buttons["Undo latest confirmation"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        undo.tap()

        let restored = NSPredicate(
            format: "value == %@",
            "Latest confirmation removed. Previous one remains."
        )
        expectation(for: restored, evaluatedWith: boardRow)
        waitForExpectations(timeout: 3)

        app.buttons["More actions"].tap()
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        undo.tap()

        let unknown = NSPredicate(format: "value == %@", "No record yet. Easy fix.")
        expectation(for: unknown, evaluatedWith: boardRow)
        waitForExpectations(timeout: 3)
    }
}
