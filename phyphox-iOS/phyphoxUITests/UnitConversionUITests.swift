//
//  UnitConversionUITests.swift
//  phyphoxUITests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest

// phyphox-test: unit-conversion-ui
//The unit dialog on the screen (phyphox-docs docs/file-format/units.md, "Switching a unit by hand"), over
//corpus/generated/unit-references.phyphox: tapping the unit of a value and of an edit element, and an axis title of a
//maximized graph, opens the dialog listing that quantity's units with the experiment's unit marked; choosing another
//one changes the displayed text immediately while /get still carries the original values; the Unit system setting
//converts every convertible element on load and skips the exclusions. Mirrors Android's UnitConversionUiTest.
final class UnitConversionUITests: XCTestCase {
    private let port = 8081
    private var base: String { "http://127.0.0.1:\(port)" }

    private func launch(setting: String? = nil) throws -> XCUIApplication {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // phyphoxUITests
            .deletingLastPathComponent()  // phyphox-iOS
            .deletingLastPathComponent()
        let fixture = repository.deletingLastPathComponent()
            .appendingPathComponent("phyphox-docs/corpus/generated/unit-references.phyphox")
        guard FileManager.default.fileExists(atPath: fixture.path) else {
            throw XCTSkip("phyphox-docs (corpus/generated/unit-references.phyphox) is not checked out next to this repository - unit conversion not tested")
        }

        let app = XCUIApplication()
        app.launchArguments = ["-phyphoxUrl", fixture.absoluteString,
                               "-phyphoxRemote", "-phyphoxRemotePort", String(port),
                               "-phyphoxAutoConfirm",
                               "-AppleLocale", "en_US", "-AppleLanguages", "(en)",
                               //The Unit system setting as the Settings app would leave it (a launch argument sets the default)
                               "-unitSystem", setting ?? "experiment"]
        app.launch()

        XCTAssertTrue(waitForAPI(seconds: 20), "the experiment did not open or the remote API did not come up")
        XCTAssertTrue(app.staticTexts["Distance"].waitForExistence(timeout: 5), "the value elements are on screen")
        return app
    }

    // MARK: - the remote API as the oracle

    private func get(_ path: String, timeout: TimeInterval = 5) -> [String: Any]? {
        guard let url = URL(string: base + path) else { return nil }
        var result: [String: Any]?
        let done = expectation(description: "GET \(path)")
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data {
                result = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            }
            done.fulfill()
        }.resume()
        _ = XCTWaiter().wait(for: [done], timeout: timeout)
        return result
    }

    private func waitForAPI(seconds: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if get("/config", timeout: 3) != nil { return true }
        }
        return false
    }

    private func buffer(_ name: String) -> [Double] {
        guard let json = get("/get?\(name)=full"),
              let buffers = json["buffer"] as? [String: Any],
              let entry = buffers[name] as? [String: Any],
              let values = entry["buffer"] as? [Any] else { return [] }
        return values.compactMap { ($0 as? NSNumber)?.doubleValue }
    }

    private func expectBuffer(_ name: String, toEqual expected: [Double], timeout: TimeInterval = 5, _ message: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        var last: [Double] = []
        repeat {
            last = buffer(name)
            if last.count == expected.count, zip(last, expected).allSatisfy({ abs($0 - $1) <= 1e-6 }) {
                return
            }
        } while Date() < deadline
        XCTFail("\(message): \(name) holds \(last), expected \(expected)", file: file, line: line)
    }

    // MARK: - the elements

    ///The unit text of a value element ("value.unit") or an edit element ("edit.unit") showing this symbol
    private func unitText(_ identifier: String, _ symbol: String, in app: XCUIApplication) -> XCUIElement {
        return app.descendants(matching: .any).matching(identifier: identifier).matching(NSPredicate(format: "label == %@", symbol)).firstMatch
    }

    ///A number as a value element shows it (the label carries a trailing space)
    private func number(_ text: String, in app: XCUIApplication) -> XCUIElement {
        return app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }

    ///The rows of the unit dialog, an action sheet carrying a table (scoped to it: the page's own cells hold the same symbols)
    private func dialogRow(_ title: String, in app: XCUIApplication) -> XCUIElement {
        return app.tables["unit.dialog"].cells.staticTexts[title].firstMatch
    }

    private func dialogCell(_ title: String, in app: XCUIApplication) -> XCUIElement {
        return app.tables["unit.dialog"].cells.containing(.staticText, identifier: title).firstMatch
    }

    // MARK: - the tests

    // phyphox-test: unit-conversion-ui
    func testTheValueUnitOpensTheDialogAndSwitchesTheUnit() throws {
        let app = try launch()
        XCTAssertTrue(number("150.0", in: app).exists, "the distance shows in the experiment's unit")

        unitText("value.unit", "cm", in: app).tap()
        XCTAssertTrue(dialogRow("cm (default)", in: app).waitForExistence(timeout: 5), "the dialog marks the experiment's unit")
        XCTAssertTrue(dialogRow("in", in: app).exists, "and lists the other units of the quantity")
        XCTAssertTrue(app.staticTexts["Metric (SI)"].exists, "grouped by system")
        XCTAssertTrue(app.staticTexts["Imperial / US customary"].exists)
        dialogRow("m", in: app).tap()

        XCTAssertTrue(number("1.500", in: app).waitForExistence(timeout: 5), "the value shows in metres, with the precision rule")
        XCTAssertTrue(unitText("value.unit", "m", in: app).exists)
        expectBuffer("distance", toEqual: [1.5], "the buffer keeps the original value")

        //the current unit is checked when the dialog opens again; choosing it again closes the dialog and keeps it
        unitText("value.unit", "m", in: app).tap()
        let current = dialogCell("m", in: app)
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        XCTAssertTrue(current.isSelected, "the current unit is marked")
        XCTAssertFalse(dialogCell("cm (default)", in: app).isSelected, "and the experiment's unit is not")
        dialogRow("m", in: app).tap()
        XCTAssertTrue(dialogRow("cm (default)", in: app).waitForNonExistence(timeout: 5), "the dialog closed")
        XCTAssertTrue(number("1.500", in: app).exists, "the unit stays")
    }

    // phyphox-test: unit-conversion-ui
    func testTheEditUnitConvertsTheFieldAndSendsTheTypedValueBack() throws {
        let app = try launch()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "0.5")

        unitText("edit.unit", "m", in: app).tap()
        XCTAssertTrue(dialogRow("ft", in: app).waitForExistence(timeout: 5), "the dialog opened for the edit element")
        dialogRow("ft", in: app).tap()
        let deadline = Date().addingTimeInterval(5)
        while (field.value as? String) != "1.64042" && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertEqual(field.value as? String, "1.64042", "the field shows the value in feet, six significant digits")
        XCTAssertTrue(unitText("edit.unit", "ft", in: app).exists)

        field.tap()
        field.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) {
            app.menuItems["Select All"].tap()
        }
        field.typeText("1")
        app.buttons["OK"].tap()
        expectBuffer("length", toEqual: [0.3048], "the typed value arrives in the buffer converted back to metres")
    }

    // phyphox-test: unit-conversion-ui
    func testAnAxisTitleOfTheMaximizedGraphOpensTheDialog() throws {
        let app = try launch()
        let title = app.staticTexts["Acceleration"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        XCTAssertTrue(app.buttons["Pan and zoom"].waitForExistence(timeout: 5), "the graph is maximized")

        let axis = app.staticTexts["a (m/s²)"]
        XCTAssertTrue(axis.waitForExistence(timeout: 5))
        axis.tap()
        XCTAssertTrue(dialogRow("m/s² (default)", in: app).waitForExistence(timeout: 5), "the dialog opened for the y axis")
        dialogRow("ft/s²", in: app).tap()
        XCTAssertTrue(app.staticTexts["a (ft/s²)"].waitForExistence(timeout: 5), "the axis title shows the chosen unit")
        XCTAssertTrue(app.buttons["Pan and zoom"].exists, "the graph stays maximized")

        app.staticTexts["Acceleration"].tap()
        XCTAssertTrue(app.staticTexts["Distance"].waitForExistence(timeout: 5), "the page comes back")
        XCTAssertTrue(app.staticTexts["a (ft/s²)"].exists, "the choice holds while the experiment is open")
    }

    // phyphox-test: unit-conversion-ui
    func testTheImperialSettingConvertsOnLoadAndSkipsTheExclusions() throws {
        let app = try launch(setting: "imperial")
        XCTAssertTrue(number("59.06", in: app).waitForExistence(timeout: 5), "cm becomes inches, one decimal more")
        XCTAssertTrue(unitText("value.unit", "in", in: app).exists)
        XCTAssertTrue(number("70.7", in: app).exists, "°C becomes °F")
        XCTAssertTrue(unitText("value.unit", "m/s³", in: app).exists, "a text unit stays")
        XCTAssertTrue(unitText("edit.unit", "ft", in: app).exists)
        XCTAssertTrue(app.staticTexts["a (ft/s²)"].exists, "the graph axis converts")
        XCTAssertTrue(app.staticTexts["t (s)"].exists, "a common unit stays")
        XCTAssertTrue(app.staticTexts["B (µT)"].exists, "a unit without counterpart stays")
        expectBuffer("distance", toEqual: [1.5], "the data is untouched")
        expectBuffer("temperature", toEqual: [21.5], "the data is untouched")
    }
}
