//
//  SwitchBypassedUITests.swift
//  phyphoxUITests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest

//Everything the host-controlled switches bypass, exercised WITHOUT them (test-matrix row
//switch-bypassed-ui): the switches must never mask a broken user path. So no -phyphoxRemote and
//no -phyphoxAutoConfirm here - the menu toggle has to enable remote access, and every notice the
//auto-confirm skips has to appear and be dismissible by hand.
//
//-phyphoxUrl stays in use where a fixture has to reach the app: it only replaces the file being
//opened, not any dialog. The one path it does bypass - the system's open-in confirmation - is
//covered by opening a phyphox:// URL through the system instead.
final class SwitchBypassedUITests: XCTestCase {
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments + ["-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
        app.launch()
        return app
    }

    private func fixture(_ name: String) throws -> URL {
        guard let fixtures = ViewBehaviorTests.fixturesDirectory else {
            throw XCTSkip("phyphox-docs is not checked out next to this repository")
        }
        return fixtures.appendingPathComponent("\(name).phyphox")
    }

    private func networkFixture(_ name: String) throws -> URL {
        guard let fixtures = ViewBehaviorTests.fixturesDirectory else {
            throw XCTSkip("phyphox-docs is not checked out next to this repository")
        }
        return fixtures.deletingLastPathComponent().appendingPathComponent("network/\(name).phyphox")
    }

    // phyphox-test: switch-bypassed-ui
    func testMenuTogglesRemoteAccess() throws {
        //No -phyphoxRemote: what is tested is the path a user takes
        let app = launch(["-phyphoxUrl", "phyphox://asset=tone_generator.phyphox", "-phyphoxAutoConfirm"])
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 20))

        app.buttons["Actions"].tap()
        XCTAssertTrue(app.buttons["Enable remote access"].waitForExistence(timeout: 5))
        app.buttons["Enable remote access"].tap()

        let warning = app.alerts.firstMatch
        XCTAssertTrue(warning.waitForExistence(timeout: 5), "the warning about what remote access exposes")
        warning.buttons["OK"].tap()

        //The server is up on the configured port, which is 80 unless a user changed it
        XCTAssertTrue(apiAnswers(port: 80, within: 15), "the menu toggle really opens the server")
    }

    // phyphox-test: switch-bypassed-ui
    func testNetworkPrivacyNoticeAppearsAndIsAccepted() throws {
        let url = try networkFixture("http-get-receive")
        let app = launch(["-phyphoxUrl", url.absoluteString])

        let notice = app.alerts.firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 20), "the network privacy notice appears without auto-confirm")
        XCTAssertTrue(notice.staticTexts.element(matching: NSPredicate(format: "label CONTAINS[c] 'network'")).exists,
                      "and says what it is about")

        //It is a notice, not a choice: OK, plus the optional link to the experiment's policy.
        //There is no decline on iOS - reported to the docs session, since the matrix row expects
        //an accept AND a decline path.
        XCTAssertFalse(notice.buttons["Cancel"].exists, "iOS offers no decline for this notice")

        notice.buttons["OK"].tap()
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 15),
                      "accepting continues into the experiment")
    }

    // phyphox-test: switch-bypassed-ui
    func testPhotosensitivityWarningAppears() throws {
        //The strobe experiment can flash the flashlight, so it warns every time it is opened
        let app = launch(["-phyphoxUrl", "phyphox://asset=strobe.phyphox"])

        let warning = app.alerts.firstMatch
        XCTAssertTrue(warning.waitForExistence(timeout: 20), "the photosensitivity warning appears")
        XCTAssertTrue(warning.staticTexts.element(matching:
            NSPredicate(format: "label CONTAINS[c] 'flash' OR label CONTAINS[c] 'photosensitiv' OR label CONTAINS[c] 'seizure'")).exists,
                      "and warns about what it is going to do")

        warning.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 15), "and the experiment opens")
    }

    // phyphox-test: switch-bypassed-ui
    func testSaveLocallyOfferAppearsForADownloadedExperiment() throws {
        //A fixture opened from a file is not part of the collection, so the app offers to keep it
        let url = try fixture("values")
        let app = launch(["-phyphoxUrl", url.absoluteString])

        let offer = app.alerts.firstMatch
        XCTAssertTrue(offer.waitForExistence(timeout: 20), "the app offers to save the experiment")
        XCTAssertGreaterThanOrEqual(offer.buttons.count, 2, "and the offer can be declined")

        //Declining leaves the experiment open but unsaved
        let decline = offer.buttons["Cancel"].exists ? offer.buttons["Cancel"] : offer.buttons.element(boundBy: offer.buttons.count - 1)
        decline.tap()
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 15), "the experiment is open either way")
    }

    // phyphox-test: switch-bypassed-ui
    func testRegularPhyphoxURLOpenPath() throws {
        guard #available(iOS 16.4, *) else { throw XCTSkip("XCUISystem.open needs iOS 16.4") }

        //Not -phyphoxUrl: the URL goes through the system, which is the path a QR code takes -
        //including the confirmation iOS shows before handing a URL to an app
        let app = launch()
        XCTAssertTrue(app.staticTexts["Raw Sensors"].waitForExistence(timeout: 20))

        XCUIDevice.shared.system.open(URL(string: "phyphox://asset=tone_generator.phyphox")!)

        //The confirmation is a system alert; it belongs to springboard, not to the app
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let confirmation = springboard.alerts.firstMatch
        if confirmation.waitForExistence(timeout: 10) {
            let open = confirmation.buttons["Open"].exists ? confirmation.buttons["Open"]
                                                           : confirmation.buttons.element(boundBy: confirmation.buttons.count - 1)
            open.tap()
        }

        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 20),
                      "the experiment opens through the regular URL path")
    }

    // MARK: - helpers

    private func apiAnswers(port: Int, within seconds: TimeInterval) -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)/config") else { return false }
        let deadline = Date().addingTimeInterval(seconds)
        repeat {
            var reachable = false
            let done = expectation(description: "config")
            let task = URLSession.shared.dataTask(with: url) { data, _, _ in
                reachable = data != nil && !(data!.isEmpty)
                done.fulfill()
            }
            task.resume()
            wait(for: [done], timeout: 5)
            if reachable { return true }
        } while Date() < deadline
        return false
    }
}
