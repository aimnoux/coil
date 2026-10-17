import XCTest

/// End-to-end checks of the main flows, run against an empty in-memory store.
@MainActor
final class CoilUITests: XCTestCase {
    var app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func launch(sampleData: Bool = false) {
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if sampleData { app.launchArguments.append("-sampleData") }
        app.launch()
    }

    /// Adds a habit through the template picker: from scratch, or by searching a template.
    private func addHabit(name: String? = nil, template: String? = nil) {
        app.buttons["Add Habit"].firstMatch.tap()
        if let template {
            let search = app.searchFields.firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            search.tap()
            search.typeText(template)
            app.staticTexts[template].firstMatch.tap()
        } else {
            app.staticTexts["Create Your Own"].tap()
        }
        if let name {
            let field = app.textFields["habit-name-field"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            field.typeText(name)
        }
        app.buttons["Save"].tap()
    }

    func testCreateHabitFromScratch() {
        launch()
        addHabit(name: "Floss")
        XCTAssertTrue(app.descendants(matching: .any)["habit-Floss"].waitForExistence(timeout: 5))
    }

    func testCreateHabitFromTemplate() {
        launch()
        addHabit(template: "Drink water")
        XCTAssertTrue(app.descendants(matching: .any)["habit-Drink water"].waitForExistence(timeout: 5))
    }

    func testCheckOffToday() {
        launch()
        addHabit(name: "Stretch")
        let today = app.buttons["day-Stretch-0"]
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        today.tap()
        XCTAssertEqual(today.value as? String, "Done")
    }

    func testOpenHabitAndGoBack() {
        launch(sampleData: true)
        let habit = app.descendants(matching: .any)["habit-Meditate"]
        XCTAssertTrue(habit.waitForExistence(timeout: 5))
        habit.tap()
        XCTAssertTrue(app.staticTexts["Overview"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(habit.waitForExistence(timeout: 5))
    }

    func testQuitHabitRecordsASlip() {
        launch()
        addHabit(template: "No smoking")
        app.descendants(matching: .any)["habit-No smoking"].tap()
        let slip = app.buttons["Record a Slip Today"]
        XCTAssertTrue(slip.waitForExistence(timeout: 5))
        slip.tap()
        app.buttons["Record Slip"].tap()
        let disabled = expectation(for: NSPredicate(format: "isEnabled == false"), evaluatedWith: slip)
        wait(for: [disabled], timeout: 5)
    }

    func testDeleteThenUndo() {
        launch()
        addHabit(name: "Journal")
        let habit = app.descendants(matching: .any)["habit-Journal"]
        XCTAssertTrue(habit.waitForExistence(timeout: 5))
        habit.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        app.buttons["Delete Journal"].tap()
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 3))
        app.buttons["Undo"].tap()
        XCTAssertTrue(habit.waitForExistence(timeout: 5))
    }

    func testTimerSavesASession() {
        launch()
        addHabit(template: "Meditate 10 minutes")
        app.descendants(matching: .any)["habit-Meditate 10 minutes"].tap()
        let start = app.buttons["Start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        sleep(2)
        app.buttons["Stop"].tap()
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["History"].exists)
    }
}
