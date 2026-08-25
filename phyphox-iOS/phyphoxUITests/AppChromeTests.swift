//
//  AppChromeTests.swift
//  phyphoxUITests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest

//The screens around an experiment (test-matrix row app-chrome): the collection with its
//categories, the info menu and the settings it leads to, the experiment menu and every dialog it
//opens, rotation on both screens, and the path a user hits when a sensor is missing.
//
//These run against the shipped collection, in English with a pinned locale, so what they assert
//is the app's own chrome rather than any fixture.
final class AppChromeTests: XCTestCase {
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments + ["-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
        app.launch()
        return app
    }

    private func openToneGenerator() -> XCUIApplication {
        let app = launch(["-phyphoxUrl", "phyphox://asset=tone_generator.phyphox", "-phyphoxAutoConfirm"])
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 20), "the experiment screen is up")
        return app
    }

    // MARK: - the collection

    // phyphox-test: app-chrome
    func testCollectionListsCategoriesInOrder() throws {
        let app = launch()

        XCTAssertTrue(app.staticTexts["Raw Sensors"].waitForExistence(timeout: 20),
                      "the collection shows its first category")
        XCTAssertTrue(app.staticTexts["Acoustics"].exists, "and the next one")

        //Categories keep the order the collection defines, not an alphabetical one
        XCTAssertLessThan(app.staticTexts["Raw Sensors"].frame.minY, app.staticTexts["Acoustics"].frame.minY,
                          "Raw Sensors comes before Acoustics")

        //Every category holds experiments, each with a title and a description
        XCTAssertGreaterThan(app.cells.count, 10, "the shipped collection is listed")
        XCTAssertTrue(app.staticTexts["Acceleration with g"].exists, "a known experiment is there")

        //The bar carries the two entry points into the chrome
        XCTAssertTrue(app.buttons["More Info"].exists)
        XCTAssertTrue(app.buttons["Add"].exists)
    }

    // phyphox-test: app-chrome
    func testInfoMenuAndSettings() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["More Info"].waitForExistence(timeout: 20))

        app.buttons["More Info"].tap()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5), "the info menu opens")
        for entry in ["Credits", "Experiment ideas and instructions", "Frequently asked questions",
                      "Remote control help", "Settings", "Device info"] {
            XCTAssertTrue(app.buttons[entry].exists, "the info menu offers \(entry)")
        }

        //Settings is a screen of its own and comes back
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10), "settings opens")
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }
        XCTAssertTrue(app.staticTexts["Raw Sensors"].waitForExistence(timeout: 10), "and returns to the collection")
    }

    // MARK: - the experiment menu and its dialogs

    // phyphox-test: app-chrome
    func testExperimentMenuOffersEveryAction() throws {
        let app = openToneGenerator()

        app.buttons["Actions"].tap()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5), "the actions menu opens")
        for action in ["Experiment info", "Export Data", "Share screenshot", "Timed run",
                       "Enable remote access", "Save experiment state"] {
            XCTAssertTrue(app.buttons[action].exists, "the menu offers \(action)")
        }
        dismissSheet(app)
    }

    // phyphox-test: app-chrome
    func testTimedRunDialog() throws {
        let app = openToneGenerator()

        app.buttons["Actions"].tap()
        XCTAssertTrue(app.buttons["Timed run"].waitForExistence(timeout: 5))
        app.buttons["Timed run"].tap()

        let dialog = app.alerts.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 5), "the timed run dialog opens")
        //It configures a delay and a duration before starting
        XCTAssertGreaterThanOrEqual(dialog.textFields.count, 2, "it asks for delay and duration")
        tapCancel(in: dialog, app: app)
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 5), "cancelling returns to the experiment")
    }

    // phyphox-test: app-chrome
    func testExportDialog() throws {
        let app = openToneGenerator()

        app.buttons["Actions"].tap()
        XCTAssertTrue(app.buttons["Export Data"].waitForExistence(timeout: 5))
        app.buttons["Export Data"].tap()

        let dialog = app.alerts.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 5), "the export dialog opens")
        tapCancel(in: dialog, app: app)
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 5))
    }

    // phyphox-test: app-chrome
    func testExperimentInfoScreen() throws {
        let app = openToneGenerator()

        app.buttons["Actions"].tap()
        XCTAssertTrue(app.buttons["Experiment info"].waitForExistence(timeout: 5))
        app.buttons["Experiment info"].tap()

        //The info screen carries the experiment's description and links to the wiki, and closes
        //with its own button rather than a navigation back - it is presented over the experiment
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 10), "the info screen opens")
        XCTAssertTrue(app.buttons["Wiki"].exists, "and offers the link to the documentation")
        XCTAssertTrue(app.staticTexts.element(matching: NSPredicate(format: "label CONTAINS[c] 'tone'"))
                        .exists, "and describes the experiment")

        app.buttons["Close"].tap()
        XCTAssertFalse(app.buttons["Close"].waitForExistence(timeout: 3), "closing dismisses it")
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 10), "and the experiment is back")
    }

    // MARK: - rotation

    // phyphox-test: app-chrome
    func testRotationOnBothScreens() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Raw Sensors"].waitForExistence(timeout: 20))

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.staticTexts["Raw Sensors"].waitForExistence(timeout: 10),
                      "the collection survives the rotation")
        XCUIDevice.shared.orientation = .portrait

        let experiment = openToneGenerator()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(experiment.buttons["Actions"].waitForExistence(timeout: 10),
                      "the experiment screen survives the rotation")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(experiment.buttons["Actions"].waitForExistence(timeout: 10), "and back")
    }

    // MARK: - the path when a sensor is missing

    // phyphox-test: app-chrome
    func testSensorNotAvailableIsExplained() throws {
        //A simulator has no accelerometer: opening that experiment must explain itself rather
        //than open an experiment that cannot measure
        let app = launch(["-phyphoxUrl", "phyphox://asset=accelerometer.phyphox", "-phyphoxAutoConfirm"])

        let dialog = app.alerts.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 20), "the app explains the missing sensor")
        XCTAssertTrue(dialog.staticTexts.element(matching: NSPredicate(format: "label CONTAINS[c] 'sensor'"))
                        .exists, "and names the sensor as the reason")
        dialog.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Raw Sensors"].waitForExistence(timeout: 10),
                      "and stays in the collection")
    }

    // MARK: - helpers

    private func dismissSheet(_ app: XCUIApplication) {
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        } else {
            //An action sheet on iPad is a popover: a tap outside closes it
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
        }
    }

    private func tapCancel(in dialog: XCUIElement, app: XCUIApplication) {
        if dialog.buttons["Cancel"].exists {
            dialog.buttons["Cancel"].tap()
        } else {
            dialog.buttons.element(boundBy: dialog.buttons.count - 1).tap()
        }
    }
}
