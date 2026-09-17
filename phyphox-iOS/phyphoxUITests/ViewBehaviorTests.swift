//
//  ViewBehaviorTests.swift
//  phyphoxUITests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest

//Interaction tests over the view fixtures in phyphox-docs fixtures/views/ (test-matrix row
//view-behavior): drive every control and assert the effect on its output buffer via the remote API.
final class ViewBehaviorTests: XCTestCase {
    private let port = 8081
    private var base: String { "http://127.0.0.1:\(port)" }

    //The phyphox-docs checkout next to this repository; #filePath resolves since tests run on the same machine
    static let fixturesDirectory: URL? = {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // phyphoxUITests
            .deletingLastPathComponent()  // phyphox-iOS
            .deletingLastPathComponent()
        let fixtures = repository.deletingLastPathComponent()
            .appendingPathComponent("phyphox-docs/fixtures/views", isDirectory: true)
        return FileManager.default.fileExists(atPath: fixtures.path) ? fixtures : nil
    }()

    private func launch(fixture: String) throws -> XCUIApplication {
        guard let fixtures = ViewBehaviorTests.fixturesDirectory else {
            throw XCTSkip("phyphox-docs is not checked out next to this repository - view behavior not tested")
        }
        let url = fixtures.appendingPathComponent("\(fixture).phyphox")

        let app = XCUIApplication()
        app.launchArguments = ["-phyphoxUrl", url.absoluteString,
                               "-phyphoxRemote", "-phyphoxRemotePort", String(port),
                               "-phyphoxAutoConfirm",
                               //deterministic number formatting in the fields
                               "-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
        app.launch()

        XCTAssertTrue(waitForAPI(seconds: 20), "the experiment did not open or the remote API did not come up")
        return app
    }

    // MARK: - the remote API as the oracle

    private func get(_ path: String, timeout: TimeInterval = 5) -> [String: Any]? {
        guard let url = URL(string: base + path) else { return nil }
        var result: [String: Any]?
        let done = expectation(description: "GET \(path)")
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data {
                result = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            }
            done.fulfill()
        }
        task.resume()
        //XCTWaiter, not wait(for:): no reply is an answer here, and wait(for:) would record a failure
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

    ///Waits for the buffer: the write travels through the analysis cycle, so it is not there instantly
    private func expectBuffer(_ name: String, toEqual expected: [Double], accuracy: Double = 1e-6,
                              timeout: TimeInterval = 5, _ message: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        var last: [Double] = []
        repeat {
            last = buffer(name)
            if last.count == expected.count,
               zip(last, expected).allSatisfy({ abs($0 - $1) <= accuracy }) {
                return
            }
        } while Date() < deadline
        XCTFail("\(message): \(name) holds \(last), expected \(expected)", file: file, line: line)
    }

    // MARK: - the interactions

    // phyphox-test: view-behavior
    func testEditFields() throws {
        let app = try launch(fixture: "edits")

        let fields = app.textFields
        XCTAssertEqual(fields.count, 5, "the edits fixture has five fields")

        type(2.25, into: fields.element(boundBy: 0), in: app)
        expectBuffer("plain", toEqual: [2.25], "a plain edit writes the typed value")

        type(42, into: fields.element(boundBy: 1), in: app)
        expectBuffer("bounded", toEqual: [10], "a value above max is clamped to max")
        type(-42, into: fields.element(boundBy: 1), in: app)
        expectBuffer("bounded", toEqual: [0], "a value below min is clamped to min")

        type(-5, into: fields.element(boundBy: 2), in: app)
        expectBuffer("unsigned", toEqual: [5], "an unsigned field drops the sign")
        type(2.75, into: fields.element(boundBy: 3), in: app)
        expectBuffer("integer", toEqual: [2], "an integer-only field drops the decimals")

        type(3, into: fields.element(boundBy: 4), in: app)
        expectBuffer("scaled", toEqual: [0.03], "the factor converts the entered value")
    }

    // phyphox-test: view-behavior
    func testButtonsAndToggles() throws {
        let app = try launch(fixture: "buttons-toggles")

        app.buttons["write 7"].tap()
        expectBuffer("target", toEqual: [7], "a button writes its value")

        //Each pair clears its output first (iOS replaceValues, Android clear+append), so the last one wins
        app.buttons["two writes, last wins"].tap()
        expectBuffer("log", toEqual: [2], "the second pair replaces what the first wrote")

        app.buttons["clear"].tap()
        expectBuffer("log", toEqual: [], "an empty input clears the buffer")

        let toggles = app.switches
        XCTAssertEqual(toggles.count, 2, "the fixture has two toggles")
        expectBuffer("switch1", toEqual: [1], "the toggle defaulting to on starts at 1")
        expectBuffer("switch2", toEqual: [0], "the other toggle starts at 0")

        toggles.element(boundBy: 0).tap()
        expectBuffer("switch1", toEqual: [0], "flipping the on toggle writes 0")
        toggles.element(boundBy: 1).tap()
        expectBuffer("switch2", toEqual: [1], "flipping the off toggle writes 1")
    }

    // phyphox-test: view-behavior
    func testSlidersAndDropdown() throws {
        let app = try launch(fixture: "sliders-dropdowns")

        //The range slider is a custom control whose two thumbs are accessibility elements (RangeSlider)
        let sliders = app.sliders
        XCTAssertEqual(sliders.count, 2, "the plain and the coarse slider are UISliders")

        adjust(sliders.element(boundBy: 0), to: 1.0, until: [5], in: "s1",
               "a slider dragged to the end writes its maximum")
        adjust(sliders.element(boundBy: 0), to: 0.0, until: [0], in: "s1",
               "and its minimum at the other end")

        //stepSize=10 on 0...50: whatever the drag lands on is quantised to a multiple of ten
        adjust(sliders.element(boundBy: 1), to: 1.0, until: [50], in: "coarse",
               "the coarse slider reaches its maximum")
        sliders.element(boundBy: 1).adjust(toNormalizedSliderPosition: 0.62)
        let coarse = buffer("coarse")
        XCTAssertEqual(coarse.count, 1)
        XCTAssertEqual(coarse.first?.truncatingRemainder(dividingBy: 10), 0,
                       "the step size quantises the value, got \(coarse)")

        let lower = app.otherElements["Lower value"]
        let upper = app.otherElements["Upper value"]
        XCTAssertTrue(lower.waitForExistence(timeout: 5), "the lower thumb is reachable")
        XCTAssertTrue(upper.exists, "the upper thumb is reachable")
        XCTAssertEqual(lower.value as? String, "20", "the thumb reports the value it stands for")
        XCTAssertEqual(upper.value as? String, "60")

        //Dragged by touch (XCUITest has no accessibility adjustment); the overshoot past the left end is clamped
        lower.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1,
                   thenDragTo: lower.coordinate(withNormalizedOffset: CGVector(dx: -2, dy: 0.5)))
        expectBuffer("lower", toEqual: [0], "the lower handle writes the lower output")
        expectBuffer("upper", toEqual: [60], "and leaves the upper one where it was")
        XCTAssertEqual(lower.value as? String, "0", "and the element reports the new value")

        //The dropdown writes the value of the entry, not its position
        let dropdown = app.buttons["slow"]
        XCTAssertTrue(dropdown.waitForExistence(timeout: 5), "the dropdown shows its default entry")
        dropdown.tap()
        let fast = app.buttons["fast"].exists ? app.buttons["fast"] : app.staticTexts["fast"]
        XCTAssertTrue(fast.waitForExistence(timeout: 5), "the entries are offered")
        fast.tap()
        expectBuffer("choice", toEqual: [2], "picking an entry writes its mapped value")
    }

    // MARK: - the starting state

    ///Switches to the page with this label through the tab bar
    private func page(to label: String, in app: XCUIApplication) {
        let tab = app.segmentedControls.buttons[label]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "the page \"\(label)\" is offered")
        tab.tap()
    }

    //A control's default fills an EMPTY buffer and never overwrites a container's init (spec remark on
    //the default attribute); both halves are asserted, since not seeding at all would break the second
    // phyphox-test: view-behavior
    func testContainerInitBeatsAControlsDefault() throws {
        let app = try launch(fixture: "init-vs-default")

        //Freshly loaded: defaults are seeded for every page at build time (Experiment.seedInputDefaults)
        let expected: [(String, Double)] = [
            ("toggle_init", 1), ("dropdown_init", 2), ("edit_init", 42), ("slider_init", 4),
            //...and where the container is empty, the default is what fills it
            ("toggle_default", 1), ("dropdown_default", 1), ("edit_default", 7), ("slider_default", 3),
        ]
        for (name, value) in expected {
            expectBuffer(name, toEqual: [value], "\(name) starts from the right value")
        }

        //Paging forces a read pass over every element of the page coming up (iOS modules only read
        //while on screen); a read pass must not turn into a write, so every buffer stays unchanged
        page(to: "default fills", in: app)
        page(to: "init wins", in: app)

        for (name, value) in expected {
            expectBuffer(name, toEqual: [value], "\(name) is unchanged after paging")
        }
    }

    //A NaN in an input element's buffer is replaced by the default as written (not clamped), and that is
    //not user input, so the experiment stays stopped (input-default-does-not-replace-nan; mirrors Android)
    // phyphox-test: view-behavior
    func testANaNIsReplacedByTheDefault() throws {
        _ = try launch(fixture: "nan-vs-default")

        expectBuffer("toggle_nan", toEqual: [1], "the toggle's default replaces the NaN")
        expectBuffer("dropdown_nan", toEqual: [2], "the dropdown's default replaces the NaN")
        expectBuffer("edit_nan", toEqual: [12], "the edit's default replaces the NaN, unclamped")
        expectBuffer("slider_nan", toEqual: [3], "the slider's default replaces the NaN")

        let status = get("/get")?["status"] as? [String: Any]
        XCTAssertNotNil(status, "the status is reported")
        XCTAssertEqual(status?["measuring"] as? Bool, false, "replacing a NaN started the experiment")
    }

    // MARK: - helpers

    ///Moves a slider and waits for the expected value, repeating the gesture if XCUITest's inexact
    ///coordinate mapping fell short; a value that never arrives still fails
    private func adjust(_ slider: XCUIElement, to position: CGFloat, until expected: [Double],
                        in name: String, _ message: String,
                        file: StaticString = #filePath, line: UInt = #line) {
        for attempt in 0..<3 {
            slider.adjust(toNormalizedSliderPosition: position)
            if attempt < 2 {
                let deadline = Date().addingTimeInterval(2)
                repeat {
                    let values = buffer(name)
                    if values.count == expected.count,
                       zip(values, expected).allSatisfy({ abs($0 - $1) <= 1e-6 }) {
                        return
                    }
                } while Date() < deadline
            }
        }
        expectBuffer(name, toEqual: expected, message, file: file, line: line)
    }

    private func type(_ value: Double, into field: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the field is on screen")
        field.tap()
        field.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) {
            app.menuItems["Select All"].tap()
        }
        let text = value == value.rounded() ? String(Int(value)) : String(value)
        field.typeText(text)

        //Commit: the field writes on the keyboard's done/return
        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        } else {
            field.typeText("\n")
        }
    }
}
