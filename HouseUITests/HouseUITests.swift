import XCTest

final class HouseUITests: XCTestCase {
    @MainActor
    func testSettingsDismissAndPlayRepeatedHands() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["dealButton"].waitForExistence(timeout: 10))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["dealButton"].waitForExistence(timeout: 5))
        for _ in 0..<2 {
            app.buttons["dealButton"].tap()
            // A natural ends immediately; otherwise stand on each active hand.
            let deadline = Date().addingTimeInterval(30)
            repeat {
                if app.buttons["Stand"].exists { app.buttons["Stand"].tap() }
                if app.buttons["dealButton"].exists { break }
                Thread.sleep(forTimeInterval: 0.3)
            } while Date() < deadline
            XCTAssertTrue(app.buttons["dealButton"].exists)
            XCTAssertEqual(app.staticTexts["roundStatus"].label, "Round complete")
        }
    }
}
