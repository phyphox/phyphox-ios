//
//  LifecycleTests.swift
//  phyphoxUITests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest

//What happens to a running experiment when the app is interrupted (test-matrix row lifecycle):
//rotation while measuring, leaving and coming back, a kill and relaunch, rapid start/stop,
//opening a second experiment, and remote access toggled in the middle of a run.
//
//The remote API is the oracle wherever the screen cannot say it: it reports whether the
//experiment is measuring, which is what "still running" actually means.
final class LifecycleTests: XCTestCase {
    private let port = 8082
    private var base: String { "http://127.0.0.1:\(port)" }

    private func launchRunning(_ fixture: String = "tone_generator") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-phyphoxUrl", "phyphox://asset=\(fixture).phyphox",
                               "-phyphoxRemote", "-phyphoxRemotePort", String(port),
                               "-phyphoxAutoConfirm",
                               "-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 20), "the experiment screen is up")
        return app
    }

    // MARK: - the remote API as the oracle

    private func status(timeout: TimeInterval = 5) -> [String: Any]? {
        guard let url = URL(string: base + "/get?") else { return nil }
        var result: [String: Any]?
        let done = expectation(description: "status")
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data,
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                result = json["status"] as? [String: Any]
            }
            done.fulfill()
        }.resume()
        wait(for: [done], timeout: timeout)
        return result
    }

    private func waitForMeasuring(_ measuring: Bool, timeout: TimeInterval = 10, _ message: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let status = status(), (status["measuring"] as? Bool) == measuring { return }
        } while Date() < deadline
        XCTFail(message, file: file, line: line)
    }

    private func apiAnswers(within seconds: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        repeat {
            if status(timeout: 2) != nil { return true }
        } while Date() < deadline
        return false
    }

    // MARK: - the tests

    // phyphox-test: lifecycle
    func testRotationWhileMeasuring() throws {
        let app = launchRunning()
        app.buttons["Play"].tap()
        waitForMeasuring(true, "the experiment starts")

        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 10), "the screen survives")
        waitForMeasuring(true, "and the measurement keeps running through the rotation")
    }

    // phyphox-test: lifecycle
    func testLeavingAndComingBack() throws {
        let app = launchRunning()
        app.buttons["Play"].tap()
        waitForMeasuring(true, "the experiment starts")

        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)

        //Leaving the app stops the measurement and takes the remote server down with it - the
        //deliberate behaviour ruled 2026-08-25, and the reason a headless run pre-grants
        //everything that could interrupt it
        XCTAssertFalse(apiAnswers(within: 3), "remote access goes down with the app")

        app.activate()
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 15), "the experiment screen comes back")
        XCTAssertTrue(apiAnswers(within: 15), "and remote access comes back with it")
        waitForMeasuring(false, "the measurement was stopped, not silently resumed")
    }

    // phyphox-test: lifecycle
    func testKillAndRelaunch() throws {
        let app = launchRunning()
        app.terminate()

        //A plain relaunch, without the experiment argument, must land in the collection
        let relaunched = XCUIApplication()
        relaunched.launchArguments = ["-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
        relaunched.launch()
        XCTAssertTrue(relaunched.staticTexts["Raw Sensors"].waitForExistence(timeout: 20),
                      "the app comes back up in the collection")
    }

    // phyphox-test: lifecycle
    func testRapidStartStop() throws {
        let app = launchRunning()
        let play = app.buttons["Play"]

        //Ten flips in a row: the button label alternates, so whatever is on screen is tapped
        for _ in 0..<5 {
            play.firstMatch.tap()
            Thread.sleep(forTimeInterval: 0.2)
            let stop = app.buttons["Pause"].exists ? app.buttons["Pause"] : app.buttons["Play"]
            stop.tap()
            Thread.sleep(forTimeInterval: 0.2)
        }

        XCTAssertTrue(app.buttons["Actions"].exists, "the app survives the hammering")
        XCTAssertTrue(apiAnswers(within: 10), "and still answers")
    }

    // phyphox-test: lifecycle
    func testOpeningASecondExperiment() throws {
        let app = launchRunning()
        app.buttons["Play"].tap()
        waitForMeasuring(true, "the first experiment runs")

        //Back to the collection and into another experiment
        app.buttons["‹"].tap()
        XCTAssertTrue(app.staticTexts["Raw Sensors"].waitForExistence(timeout: 15), "the collection is back")

        let second = app.staticTexts["Audio Scope"]
        if second.exists {
            second.tap()
            //Whatever the second experiment does with the microphone, the app must not be stuck
            XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 20)
                          || app.alerts.firstMatch.waitForExistence(timeout: 5),
                          "the second experiment opens or explains why it cannot")
        }
    }

    // phyphox-test: lifecycle
    func testRemoteAccessToggledMidRun() throws {
        //Deliberately launched without -phyphoxRemote: the toggle is the user's path
        let app = XCUIApplication()
        app.launchArguments = ["-phyphoxUrl", "phyphox://asset=tone_generator.phyphox",
                               "-phyphoxAutoConfirm", "-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 20))

        app.buttons["Play"].tap()
        app.buttons["Actions"].tap()
        XCTAssertTrue(app.buttons["Enable remote access"].waitForExistence(timeout: 5))
        app.buttons["Enable remote access"].tap()

        //The warning about what remote access exposes comes first
        let warning = app.alerts.firstMatch
        XCTAssertTrue(warning.waitForExistence(timeout: 5), "enabling warns before it opens the server")
        warning.buttons["OK"].tap()

        //The banner is a text view rather than a label, so it is matched by content across types
        let banner = app.descendants(matching: .any)
            .matching(NSPredicate(format: "value CONTAINS[c] 'http://' OR label CONTAINS[c] 'http://'"))
            .firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 10), "the address to connect to is shown")

        //And off again
        app.buttons["Actions"].tap()
        XCTAssertTrue(app.buttons["Disable remote access"].waitForExistence(timeout: 5),
                      "the menu now offers to switch it off")
        app.buttons["Disable remote access"].tap()
        XCTAssertFalse(banner.waitForExistence(timeout: 3), "and the address is gone")
    }
}
