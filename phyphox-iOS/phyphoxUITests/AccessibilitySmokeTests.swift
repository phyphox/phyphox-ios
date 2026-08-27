//
//  AccessibilitySmokeTests.swift
//  phyphoxUITests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest

//performAccessibilityAudit() over the main screens (test-matrix row accessibility-smoke).
//
//Report-only for now, as the row says: the audit's findings are printed and counted, and the
//test passes regardless. It escalates to failing once the findings have been triaged - which is
//what the printed list is for. The range slider was the first finding this work produced, and it
//is fixed; whatever remains here is the backlog.
final class AccessibilitySmokeTests: XCTestCase {
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments + ["-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
        app.launch()
        return app
    }

    ///The audit types print as raw values otherwise, which says nothing in a CI log
    @available(iOS 17.0, *)
    private static func name(of type: XCUIAccessibilityAuditType) -> String {
        var names: [String] = []
        let known: [(XCUIAccessibilityAuditType, String)] = [
            (.contrast, "contrast"), (.elementDetection, "element detection"),
            (.hitRegion, "hit region"), (.sufficientElementDescription, "element description"),
            (.dynamicType, "dynamic type"), (.textClipped, "text clipped"), (.trait, "trait")
        ]
        for (value, name) in known where type.contains(value) {
            names.append(name)
        }
        return names.isEmpty ? "\(type)" : names.joined(separator: "+")
    }

    ///Runs the audit and reports what it found without failing the test
    @available(iOS 17.0, *)
    private func audit(_ app: XCUIApplication, screen: String) {
        var findings: [String] = []
        do {
            try app.performAccessibilityAudit { issue in
                findings.append("\(AccessibilitySmokeTests.name(of: issue.auditType)): \(issue.compactDescription)")
                //Handled: the audit is report-only until its findings are triaged
                return true
            }
        } catch {
            findings.append("the audit itself failed: \(error)")
        }

        if findings.isEmpty {
            print("accessibility-smoke: \(screen) - no findings")
        } else {
            print("accessibility-smoke: \(screen) - \(findings.count) finding(s)")
            for finding in Set(findings).sorted() {
                print("   \(finding)")
            }
        }
    }

    // phyphox-test: accessibility-smoke
    func testCollectionScreen() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit needs iOS 17") }
        let app = launch()
        XCTAssertTrue(app.staticTexts["Raw Sensors"].waitForExistence(timeout: 20))
        audit(app, screen: "collection")
    }

    // phyphox-test: accessibility-smoke
    func testExperimentScreen() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit needs iOS 17") }
        let app = launch(["-phyphoxUrl", "phyphox://asset=tone_generator.phyphox", "-phyphoxAutoConfirm"])
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 20))
        audit(app, screen: "experiment")
    }

    // phyphox-test: accessibility-smoke
    func testExperimentMenuAndInfo() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit needs iOS 17") }
        let app = launch(["-phyphoxUrl", "phyphox://asset=tone_generator.phyphox", "-phyphoxAutoConfirm"])
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 20))

        app.buttons["Actions"].tap()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5))
        audit(app, screen: "experiment menu")

        app.buttons["Experiment info"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 10))
        audit(app, screen: "experiment info")
    }


    // phyphox-test: accessibility-smoke
    func testTheAddExperimentMenuIsReachable() throws {
        //The three ways into a new experiment - a QR code, a Bluetooth device, the simple
        //creator - live behind the collection's + button. On Android the same menu is drawn but
        //never made visible in the view-hierarchy sense, so TalkBack cannot reach any of it and
        //nobody noticed, because no accessibility check ever opened that menu. This one does:
        //what XCUITest sees IS the accessibility tree VoiceOver reads, so an entry that is
        //present here with a label, and hittable, is an entry VoiceOver can reach and activate.
        let app = launch()
        XCTAssertTrue(app.staticTexts["Raw Sensors"].waitForExistence(timeout: 20))

        let add = app.buttons["Add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "the + button is an element of its own")
        add.tap()

        let entries = ["Add experiment from QR code",
                       "Add experiment for Bluetooth device",
                       "Add simple experiment"]
        for entry in entries {
            let element = app.cells.staticTexts[entry].exists ? app.cells.staticTexts[entry] : app.staticTexts[entry]
            XCTAssertTrue(element.waitForExistence(timeout: 5), "\(entry) is in the accessibility tree")
            XCTAssertTrue(element.isHittable, "\(entry) can be activated")
        }

        if #available(iOS 17.0, *) {
            audit(app, screen: "add experiment menu")
        }

        //And the entries really do lead somewhere: the simple creator opens and comes back
        app.cells.staticTexts["Add simple experiment"].tap()
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 10),
                      "activating an entry opens what it promises")
    }

    // phyphox-test: accessibility-smoke
    func testViewElementsScreen() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("performAccessibilityAudit needs iOS 17") }
        //The fixtures put every interactive element on one screen, which is where an audit has
        //the most to look at - including the range slider whose thumbs are now elements
        guard let fixtures = ViewBehaviorTests.fixturesDirectory else {
            throw XCTSkip("phyphox-docs is not checked out next to this repository")
        }
        let app = launch(["-phyphoxUrl", fixtures.appendingPathComponent("sliders-dropdowns.phyphox").absoluteString,
                          "-phyphoxAutoConfirm"])
        XCTAssertTrue(app.sliders.firstMatch.waitForExistence(timeout: 20))
        audit(app, screen: "view elements")
    }
}
