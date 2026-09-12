//
//  GraphInteractionTests.swift
//  phyphoxUITests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest

//The maximized graph's tools over phyphox-docs fixtures/views/graphs-interaction.phyphox (test-matrix row
//graph-interaction): a straight line y = 2x + 1 with pick outputs, so every read-out has an exact value, and a
//graph over empty containers that has to survive every gesture (the Android 1.2.1 crash was in its pick handler).
//The plot is reached through its accessibility element, whose value reports the visible axis ranges; taps and
//drags are placed by converting data coordinates through those ranges.
final class GraphInteractionTests: XCTestCase {
    private let port = 8081
    private var base: String { "http://127.0.0.1:\(port)" }

    private func launch() throws -> XCUIApplication {
        guard let fixtures = ViewBehaviorTests.fixturesDirectory else {
            throw XCTSkip("phyphox-docs is not checked out next to this repository - graph interaction not tested")
        }
        let url = fixtures.appendingPathComponent("graphs-interaction.phyphox")
        //A checkout without the fixture (a phyphox-docs commit not yet pushed) must not read as an app defect
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

    // MARK: - the graph's elements

    ///The plot area of the graph with this label (GraphRenderer sets identifier, label and the ranges value)
    private func plot(_ label: String, in app: XCUIApplication) -> XCUIElement {
        return app.descendants(matching: .any).matching(identifier: "graph.plot").matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private struct Ranges {
        let minX, maxX, minY, maxY: Double
        var width: Double { maxX - minX }
    }

    ///The visible axis ranges, parsed from the plot's accessibility value "x from A to B, y from C to D"
    private func ranges(of plot: XCUIElement, file: StaticString = #filePath, line: UInt = #line) -> Ranges? {
        let deadline = Date().addingTimeInterval(5)
        repeat {
            if let value = plot.value as? String {
                let numbers = value.split(whereSeparator: { $0 == " " || $0 == "," })
                    .compactMap { Double($0) }
                if numbers.count >= 4 {
                    return Ranges(minX: numbers[0], maxX: numbers[1], minY: numbers[2], maxY: numbers[3])
                }
            }
        } while Date() < deadline
        XCTFail("the plot did not report its axis ranges, value is \(String(describing: plot.value))", file: file, line: line)
        return nil
    }

    ///Screen position of a data point, inside the plot
    private func coordinate(x: Double, y: Double, on plot: XCUIElement, ranges: Ranges) -> XCUICoordinate {
        let nx = (x - ranges.minX) / ranges.width
        let ny = 1 - (y - ranges.minY) / (ranges.maxY - ranges.minY)
        return plot.coordinate(withNormalizedOffset: CGVector(dx: nx, dy: ny))
    }

    ///A tap on the graph's title toggles between the page and the maximized graph
    private func toggleMaximized(_ label: String, in app: XCUIApplication) {
        let title = app.staticTexts[label]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "the graph \"\(label)\" shows its label")
        title.tap()
    }

    private func tool(_ label: String, in app: XCUIApplication) -> XCUIElement {
        return app.buttons[label]
    }

    private func menuAction(_ label: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        tool("More tools", in: app).tap()
        //The menu is an action sheet carrying a table; its rows are cells with a text label
        let action = app.cells.staticTexts[label].firstMatch
        XCTAssertTrue(action.waitForExistence(timeout: 5), "the tools menu offers \"\(label)\"", file: file, line: line)
        action.tap()
    }

    ///The read-out box the marker system shows for a pick, a drag or a fit
    private func readOut(containing fragments: [String], in app: XCUIApplication, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: fragments.map { _ in "label CONTAINS %@" }.joined(separator: " AND "),
                                    argumentArray: fragments)
        return app.staticTexts.matching(predicate).firstMatch.waitForExistence(timeout: timeout)
    }

    // MARK: - the tests

    // phyphox-test: graph-interaction
    func testMaximizeAndRestore() throws {
        let app = try launch()
        XCTAssertTrue(plot("empty", in: app).exists, "both graphs are on the page")
        XCTAssertFalse(tool("Pick", in: app).exists, "the tools are not shown on the page")

        toggleMaximized("line", in: app)
        XCTAssertTrue(tool("Pick", in: app).waitForExistence(timeout: 5), "the maximized graph shows its tools")
        XCTAssertTrue(tool("Pan and zoom", in: app).exists)
        XCTAssertTrue(tool("More tools", in: app).exists)
        XCTAssertFalse(plot("empty", in: app).exists, "the other graph is hidden while one is maximized")

        toggleMaximized("line", in: app)
        XCTAssertTrue(plot("empty", in: app).waitForExistence(timeout: 5), "collapsing restores the page")
        XCTAssertFalse(tool("Pick", in: app).exists, "and hides the tools again")
    }

    // phyphox-test: graph-interaction
    func testPickWritesTheOutputs() throws {
        let app = try launch()
        toggleMaximized("line", in: app)
        tool("Pick", in: app).tap()

        let plot = plot("line", in: app)
        guard let ranges = ranges(of: plot) else { return }
        coordinate(x: 4, y: 9, on: plot, ranges: ranges).tap()

        let found = readOut(containing: ["Point", "4.000 s", "9.000 m"], in: app)
        XCTAssertTrue(found, "the pick reads out the data point")
        let pickX = app.buttons["Pick x"]
        XCTAssertTrue(pickX.waitForExistence(timeout: 5), "the pick outputs are offered")
        pickX.tap()
        expectBuffer("picked_x", toEqual: [4], "Pick x writes the x value")
        app.buttons["Pick y"].tap()
        expectBuffer("picked_y", toEqual: [9], "Pick y writes the y value")
    }

    // phyphox-test: graph-interaction
    func testDragReadsOutDifferenceAndSlope() throws {
        let app = try launch()
        toggleMaximized("line", in: app)
        tool("Pick", in: app).tap()

        let plot = plot("line", in: app)
        guard let ranges = ranges(of: plot) else { return }
        coordinate(x: 2, y: 5, on: plot, ranges: ranges)
            .press(forDuration: 0.2, thenDragTo: coordinate(x: 6, y: 13, on: plot, ranges: ranges))

        XCTAssertTrue(readOut(containing: ["Difference", "4.000 s", "8.000 m", "Slope", "2.000"], in: app),
                      "the drag reads out the difference and the slope")
    }

    // phyphox-test: graph-interaction
    func testLinearFit() throws {
        let app = try launch()
        toggleMaximized("line", in: app)
        menuAction("Linear fit", in: app)

        XCTAssertTrue(readOut(containing: ["Linear fit", "a = 2.000", "b = 1.000"], in: app), "the fit of the line is exact")
    }

    // phyphox-test: graph-interaction
    func testPanAndResetZoom() throws {
        let app = try launch()
        toggleMaximized("line", in: app)
        tool("Pan and zoom", in: app).tap()

        let area = plot("line", in: app)
        guard let before = ranges(of: area) else { return }

        //Dragging the content left by 40 % of the plot brings the range 40 % further right
        area.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: area.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)))
        let deadline = Date().addingTimeInterval(5)
        var after = before
        repeat {
            if let now = ranges(of: area) { after = now }
        } while after.minX == before.minX && Date() < deadline
        let expectedShift = 0.4 * before.width
        XCTAssertEqual(after.minX - before.minX, expectedShift, accuracy: 0.4, "the visible x range moved with the drag")
        XCTAssertEqual(after.width, before.width, accuracy: 1e-3, "a pan does not change the zoom")

        menuAction("Reset zoom", in: app)
        let restored = Date().addingTimeInterval(5)
        var reset = after
        repeat {
            if let now = ranges(of: area) { reset = now }
        } while abs(reset.minX - before.minX) > 1e-3 && Date() < restored
        XCTAssertEqual(reset.minX, before.minX, accuracy: 1e-3, "reset zoom restores the automatic range")
        XCTAssertEqual(reset.maxX, before.maxX, accuracy: 1e-3)

        toggleMaximized("line", in: app)
        XCTAssertTrue(plot("empty", in: app).waitForExistence(timeout: 5), "the page comes back without a zoom prompt")
    }

    //Every gesture on a graph whose containers are empty: nothing may crash or tear the view down
    // phyphox-test: graph-interaction
    func testEmptyGraphSurvivesEveryGesture() throws {
        let app = try launch()
        toggleMaximized("empty", in: app)
        XCTAssertTrue(tool("Pick data", in: app).waitForExistence(timeout: 5), "the empty graph maximizes like any other")
        let area = plot("empty", in: app)

        tool("Pan and zoom", in: app).tap()
        area.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: area.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)))

        tool("Pick data", in: app).tap()
        area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        area.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.7))
            .press(forDuration: 0.2, thenDragTo: area.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)))

        menuAction("Linear fit", in: app)
        menuAction("Reset zoom", in: app)

        XCTAssertEqual(app.state, .runningForeground, "the app survived the gestures on the empty graph")
        XCTAssertTrue(tool("Pick data", in: app).exists, "the maximized graph is still standing")
        XCTAssertNotNil(get("/config"), "and the experiment is still running")

        toggleMaximized("empty", in: app)
        XCTAssertTrue(plot("line", in: app).waitForExistence(timeout: 5), "the page is restored")
    }
}
