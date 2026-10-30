import XCTest

final class HcIOSUITests: XCTestCase {
    private let env = ProcessInfo.processInfo.environment

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(user: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingNoLock",
            "-host", "127.0.0.1",
            "-port", "22",
            "-user", user ?? env["E2E_USER"] ?? "",
            "-hcPath", env["E2E_HC"] ?? "",
        ]
        app.launch()
        return app
    }

    private func text(_ app: XCUIApplication, containing value: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }

    func test1TrustAnswerAndSend() {
        let app = launch()

        XCTAssertTrue(app.staticTexts["Trust this Mac?"].waitForExistence(timeout: 20))
        XCTAssertTrue(text(app, containing: env["E2E_FINGERPRINT"] ?? "missing").exists)
        app.buttons["Trust"].tap()

        let blocked = app.buttons["row-e2e-blocked"]
        let working = app.buttons["row-e2e-working"]
        XCTAssertTrue(blocked.waitForExistence(timeout: 20))
        XCTAssertTrue(working.waitForExistence(timeout: 5))
        XCTAssertEqual(blocked.value as? String, "Needs you")
        XCTAssertLessThan(blocked.frame.minY, working.frame.minY)

        blocked.tap()
        XCTAssertTrue(text(app, containing: "Do you want to proceed?").waitForExistence(timeout: 10))
        app.buttons["Allow"].tap()
        XCTAssertTrue(text(app, containing: "got: '1'").waitForExistence(timeout: 10))

        let field = app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
        field.tap()
        field.typeText("hello e2e")
        app.buttons["Send"].tap()
        XCTAssertTrue(text(app, containing: "hello e2e").waitForExistence(timeout: 10))

        app.swipeUp()
        app.buttons["ctrl+c"].tap()
        XCTAssertTrue(app.buttons["Send ctrl+c"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        sleep(3)
        XCTAssertFalse(text(app, containing: "interrupted").exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let done = NSPredicate(format: "value == %@", "Done")
        expectation(for: done, evaluatedWith: app.buttons["row-e2e-blocked"])
        waitForExpectations(timeout: 10)
    }

    func test2WrongUserShowsAuthError() {
        let app = launch(user: "nobody-hc-ios-e2e")
        XCTAssertTrue(app.staticTexts["Not connected"].waitForExistence(timeout: 20))
        XCTAssertTrue(text(app, containing: "Permission denied").exists)
    }
}
