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
