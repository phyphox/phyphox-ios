//
//  ViewBehaviorTests.swift
//  phyphoxUITests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest

//Interaction tests over the view fixtures in phyphox-docs fixtures/views/ (test-matrix row
//view-behavior): type into the edits, press the buttons, flip the toggles, move both slider
//types, pick a dropdown entry - and assert what each interaction did to its output buffer
//through the remote API, which the fixtures wire up for exactly that purpose.
//
//The fixture is handed to the app by the launch-argument seam (-phyphoxUrl with the file URL of
//the fixture, -phyphoxRemote for the API, -phyphoxAutoConfirm for the open-time notices), so the
//app takes it through its real loading path.
final class ViewBehaviorTests: XCTestCase {
    private let port = 8081
    private var base: String { "http://127.0.0.1:\(port)" }

    //The fixtures live in the phyphox-docs checkout next to this repository; #filePath resolves
    //because the tests build and run on the same machine, and a simulator reads the host's files
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
        wait(for: [done], timeout: timeout)
        return result
    }

    private func waitForAPI(seconds: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if get("/config", timeout: 3) != nil { return true }
        }
        return false
    }

    ///The contents of one buffer, as the app reports them
    private func buffer(_ name: String) -> [Double] {
        guard let json = get("/get?\(name)=full"),
              let buffers = json["buffer"] as? [String: Any],
              let entry = buffers[name] as? [String: Any],
              let values = entry["buffer"] as? [Any] else { return [] }
        return values.compactMap { ($0 as? NSNumber)?.doubleValue }
    }

    ///Waits for a buffer to hold what the interaction should have written - the write travels
    ///through the analysis cycle, so it is not there the instant the control is released
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

        //A plain field takes what it is given
        type(2.25, into: fields.element(boundBy: 0), in: app)
        expectBuffer("plain", toEqual: [2.25], "a plain edit writes the typed value")

        //Bounds clamp on commit rather than refusing the input
        type(42, into: fields.element(boundBy: 1), in: app)
        expectBuffer("bounded", toEqual: [10], "a value above max is clamped to max")
        type(-42, into: fields.element(boundBy: 1), in: app)
        expectBuffer("bounded", toEqual: [0], "a value below min is clamped to min")

        //signed="false" and decimal="false" restrict what the field accepts at all
        type(-5, into: fields.element(boundBy: 2), in: app)
        expectBuffer("unsigned", toEqual: [5], "an unsigned field drops the sign")
        type(2.75, into: fields.element(boundBy: 3), in: app)
        expectBuffer("integer", toEqual: [2], "an integer-only field drops the decimals")

        //The factor converts the displayed unit into the buffer's unit: 3 cm is 0.03
        type(3, into: fields.element(boundBy: 4), in: app)
        expectBuffer("scaled", toEqual: [0.03], "the factor converts the entered value")
    }

    // phyphox-test: view-behavior
    func testButtonsAndToggles() throws {
        let app = try launch(fixture: "buttons-toggles")

        app.buttons["write 7"].tap()
        expectBuffer("target", toEqual: [7], "a button writes its value")

        //Every input/output pair is applied on its own and clears its output first (iOS
        //replaceValues, Android clear+append), so two pairs pointing at the same buffer leave
        //only the second value - the agreed semantics on both platforms, now stated in the spec
        app.buttons["two writes, last wins"].tap()
        expectBuffer("log", toEqual: [2], "the second pair replaces what the first wrote")

        app.buttons["clear"].tap()
        expectBuffer("log", toEqual: [], "an empty input clears the buffer")

        //The toggles start from their default and write on every flip
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

        //Two of the three are UISliders; the range slider is a custom control whose two thumbs
        //are accessibility elements of their own (see RangeSlider), which is how they are
        //addressed further down
        let sliders = app.sliders
        XCTAssertEqual(sliders.count, 2, "the plain and the coarse slider are UISliders")

        sliders.element(boundBy: 0).adjust(toNormalizedSliderPosition: 1.0)
        expectBuffer("s1", toEqual: [5], "a slider dragged to the end writes its maximum")
        sliders.element(boundBy: 0).adjust(toNormalizedSliderPosition: 0.0)
        expectBuffer("s1", toEqual: [0], "and its minimum at the other end")

        //stepSize=10 on 0...50: whatever the drag lands on is quantised to a multiple of ten
        sliders.element(boundBy: 1).adjust(toNormalizedSliderPosition: 1.0)
        expectBuffer("coarse", toEqual: [50], "the coarse slider reaches its maximum")
        sliders.element(boundBy: 1).adjust(toNormalizedSliderPosition: 0.62)
        let coarse = buffer("coarse")
        XCTAssertEqual(coarse.count, 1)
        XCTAssertEqual(coarse.first?.truncatingRemainder(dividingBy: 10), 0,
                       "the step size quantises the value, got \(coarse)")

        //The range slider's two thumbs are accessibility elements of their own, so they can be
        //found and read rather than guessed at by coordinate
        let lower = app.otherElements["Lower value"]
        let upper = app.otherElements["Upper value"]
        XCTAssertTrue(lower.waitForExistence(timeout: 5), "the lower thumb is reachable")
        XCTAssertTrue(upper.exists, "the upper thumb is reachable")
        XCTAssertEqual(lower.value as? String, "20", "the thumb reports the value it stands for")
        XCTAssertEqual(upper.value as? String, "60")

        //Dragging still happens by touch - XCUITest offers no accessibility adjustment - but it
        //starts from the thumb's own frame and simply overshoots the left end, which the slider
        //clamps
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

    // MARK: - helpers

    private func type(_ value: Double, into field: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the field is on screen")
        field.tap()
        //Clear whatever the field holds: select all, then type over it
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
