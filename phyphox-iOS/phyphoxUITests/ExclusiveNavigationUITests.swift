//
//  ExclusiveNavigationUITests.swift
//  phyphoxUITests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest

// phyphox-test: exclusive-navigation
//The ways back from a maximized graph, over phyphox-docs fixtures/views/graphs-interaction.phyphox: "‹" first closes
//the maximized graph and leaves the experiment only without one; a tab change is held back until the graph is gone;
//on either route a zoomed graph asks "Keep this view?" first, and Cancel stays. Mirrors Android's
//ExclusiveNavigationTest. The pager swipe is locked while a graph is maximized; a swipe cannot be asserted here.
final class ExclusiveNavigationUITests: XCTestCase {
    private let port = 8081
    private var base: String { "http://127.0.0.1:\(port)" }

    private func launch() throws -> XCUIApplication {
        guard let fixtures = ViewBehaviorTests.fixturesDirectory else {
            throw XCTSkip("phyphox-docs is not checked out next to this repository - exclusive navigation not tested")
        }
        let url = fixtures.appendingPathComponent("graphs-interaction.phyphox")
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("phyphox-docs has no fixtures/views/graphs-interaction.phyphox - is the phyphox-docs commit that added it pushed?")
            throw XCTSkip("fixture missing")
        }

        let app = XCUIApplication()
        app.launchArguments = ["-phyphoxUrl", url.absoluteString,
                               "-phyphoxRemote", "-phyphoxRemotePort", String(port),
                               "-phyphoxAutoConfirm",
                               "-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
        app.launch()

        XCTAssertTrue(waitForAPI(seconds: 20), "the experiment did not open or the remote API did not come up")
        XCTAssertTrue(plot("line", in: app).waitForExistence(timeout: 5), "the line graph is on screen")
        return app
    }

    private func waitForAPI(seconds: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            guard let url = URL(string: base + "/config") else { return false }
            var reached = false
            let done = expectation(description: "GET /config")
            URLSession.shared.dataTask(with: url) { data, _, _ in
                reached = data != nil
                done.fulfill()
            }.resume()
            _ = XCTWaiter().wait(for: [done], timeout: 3)
            if reached { return true }
        }
        return false
    }

    // MARK: - the graph's elements

    private func plot(_ label: String, in app: XCUIApplication) -> XCUIElement {
        return app.descendants(matching: .any).matching(identifier: "graph.plot").matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func maximize(_ label: String, in app: XCUIApplication) {
        let title = app.staticTexts[label]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "the graph \"\(label)\" shows its label")
        title.tap()
        XCTAssertTrue(app.buttons["Pick"].waitForExistence(timeout: 5), "the maximized graph shows its tools")
    }

    ///A pan in the "Pan and zoom" tool leaves the graph zoomed
    private func zoom(_ label: String, in app: XCUIApplication) {
        app.buttons["Pan and zoom"].tap()
        let area = plot(label, in: app)
        area.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: area.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)))
    }

    private func back(in app: XCUIApplication) -> XCUIElement {
        return app.navigationBars.buttons["‹"].firstMatch
    }

    private func tab(_ label: String, in app: XCUIApplication) -> XCUIElement {
        return app.segmentedControls.buttons[label].firstMatch
    }

    private var question: String { "Keep this view?" }

    ///A screenshot in the result bundle, to look at the dialog after a run
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - the tests

    // phyphox-test: exclusive-navigation
    func testBackClosesTheMaximizedGraphFirstAndLeavesOnlyAfterwards() throws {
        let app = try launch()
        maximize("line", in: app)

        back(in: app).tap()
        XCTAssertTrue(plot("empty", in: app).waitForExistence(timeout: 5), "the first ‹ restores the page")
        XCTAssertTrue(plot("line", in: app).exists, "and stays in the experiment")

        back(in: app).tap()
        //A run longer than ten seconds asks before leaving
        let leave = app.alerts.buttons["Leave"]
        if leave.waitForExistence(timeout: 2) {
            leave.tap()
        }
        XCTAssertTrue(plot("line", in: app).waitForNonExistence(timeout: 5), "the second ‹ leaves the experiment")
    }

    // phyphox-test: exclusive-navigation
    func testBackAsksAboutAZoomFirstAndCancelStays() throws {
        let app = try launch()
        maximize("line", in: app)
        zoom("line", in: app)

        back(in: app).tap()
        XCTAssertTrue(app.staticTexts[question].waitForExistence(timeout: 5), "a zoomed graph asks before it closes")
        attach(app, "keep-this-view")
        //"More options…" expands the per-axis section in place; Cancel still stays
        app.buttons["More options…"].tap()
        XCTAssertTrue(app.staticTexts["Also apply to other graphs with…"].waitForExistence(timeout: 5), "the axis section offers the other graphs")
        XCTAssertFalse(app.staticTexts["Keep and follow new data"].exists, "follow is only offered on an incremental x axis, and the line is not one")
        attach(app, "keep-this-view-more-options")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts[question].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Pick"].exists, "Cancel keeps the graph maximized")
        XCTAssertFalse(plot("empty", in: app).exists)

        back(in: app).tap()
        XCTAssertTrue(app.staticTexts[question].waitForExistence(timeout: 5))
        app.buttons["Reset zoom"].tap()
        XCTAssertTrue(plot("empty", in: app).waitForExistence(timeout: 5), "answered, the page comes back")
        XCTAssertTrue(plot("line", in: app).exists, "and the experiment stays open")
    }

    // phyphox-test: exclusive-navigation
    func testATabChangeWaitsForTheMaximizedGraphAndAZoomedGraphAsksFirst() throws {
        let app = try launch()
        let other = app.staticTexts["Other value"]

        //not zoomed: the tab change closes the graph and moves on at once
        maximize("line", in: app)
        tab("Other", in: app).tap()
        XCTAssertTrue(other.waitForExistence(timeout: 5), "the page moves to the tapped tab")
        tab("Interaction", in: app).tap()
        XCTAssertTrue(plot("line", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Pick"].exists, "the graph is no longer maximized")

        //zoomed: the question comes up, the page stays, Cancel keeps the maximized graph
        maximize("line", in: app)
        zoom("line", in: app)
        tab("Other", in: app).tap()
        XCTAssertTrue(app.staticTexts[question].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts[question].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Pick"].exists, "Cancel stays on the maximized graph")
        XCTAssertFalse(other.exists, "and on the current tab")

        //answered: the graph closes and the page moves to the tab that was tapped
        tab("Other", in: app).tap()
        XCTAssertTrue(app.staticTexts[question].waitForExistence(timeout: 5))
        app.buttons["Keep this section"].tap()
        XCTAssertTrue(other.waitForExistence(timeout: 5), "the page moves once the graph is gone")
    }
}
