//
//  SaveToCollectionTests.swift
//  phyphoxUITests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest

//Saving a container to the experiment collection (test-matrix row save-to-collection), the flow
//-phyphoxAutoConfirm deliberately declines: opened from outside the collection, an experiment is
//offered for saving, and accepting has to bring its resources along. The container fixtures come
//from phyphox-docs/fixtures/containers.
//
//What the collection gains is state that outlives the test, so every saved entry is deleted
//again through the app's own delete flow.
final class SaveToCollectionTests: XCTestCase {
    private let port = 8084
    private var savedTitles: [String] = []

    ///Everything these fixtures can leave in the collection. Cleaning up all of them rather than
    ///only what this test saved matters because the state outlives the process: a run that dies
    ///between saving and deleting would otherwise poison the next one - the resource folder it
    ///left behind makes the next save of the same experiment fail.
    private static let fixtureTitles = ["Container fixture with resource",
                                        "Container fixture A", "Container fixture B"]

    override func tearDownWithError() throws {
        let app = XCUIApplication()
        if app.state != .runningForeground {
            app.launchArguments = ["-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
            app.launch()
        }
        returnToCollection(app)

        for title in SaveToCollectionTests.fixtureTitles where scrollToEntry(app, title: title, swipes: 8) != nil {
            deleteFromCollection(app, title: title)
        }
        savedTitles = []

        try super.tearDownWithError()
    }

    private func container(_ name: String) throws -> URL {
        guard let fixtures = ViewBehaviorTests.fixturesDirectory else {
            throw XCTSkip("phyphox-docs is not checked out next to this repository")
        }
        let url = fixtures.deletingLastPathComponent().appendingPathComponent("containers/\(name)")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("the phyphox-docs checkout has no fixtures/containers/\(name)")
        }
        return url
    }

    private func launch(_ container: URL, remote: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        //No -phyphoxAutoConfirm: the offer to save is the whole point here
        app.launchArguments = ["-phyphoxUrl", container.absoluteString,
                               "-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
            + (remote ? ["-phyphoxRemote", "-phyphoxRemotePort", String(port)] : [])
        app.launch()
        return app
    }

    // MARK: - the tests

    // phyphox-test: save-to-collection
    func testSavingAnExperimentTakesItsResourceAlong() throws {
        let app = launch(try container("with-resource.zip"), remote: true)

        let offer = app.alerts.firstMatch
        XCTAssertTrue(offer.waitForExistence(timeout: 30), "the app offers to add the experiment to the collection")
        XCTAssertTrue(offer.buttons["Save to collection"].exists)
        offer.buttons["Save to collection"].tap()
        savedTitles = ["Container fixture with resource"]

        //Saving confirms with an alert of its own, which has to go before anything else can be
        //tapped (Experiment.saveLocally, quiet: false)
        let confirmation = app.alerts.firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 15), "the app confirms that it saved the experiment")
        confirmation.buttons["OK"].tap()

        //Back out and in again: what is opened now is the saved copy, whose resources live in the
        //per-experiment folder named after the hex CRC32 of the experiment file
        returnToCollection(app)
        let entry = try XCTUnwrap(scrollToEntry(app, title: "Container fixture with resource"),
                                  "the collection gained the entry")
        entry.tap()
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 20), "the saved experiment opens")
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 3),
                       "and is not offered for saving a second time")

        //The image element resolves its src against that folder, and so does /res - which is how
        //a test can see what the image element sees
        let resource = try XCTUnwrap(resourceOverRemoteAccess("pic.png"), "the resource is served for the saved experiment")
        XCTAssertEqual(Array(resource.prefix(4)), [0x89, 0x50, 0x4e, 0x47],
                       "the PNG the container delivered, not the \"Unknown file.\" answer")
        XCTAssertTrue(app.images.firstMatch.exists, "and the image element is on screen")
    }

    // phyphox-test: save-to-collection
    func testSavingEveryExperimentOfAContainerAtOnce() throws {
        let app = launch(try container("two-experiments.zip"))

        //A container with more than one experiment offers the picker, whose button saves them all
        let saveAll = app.buttons["Save all"]
        XCTAssertTrue(saveAll.waitForExistence(timeout: 30), "the picker for a multi-experiment container")
        saveAll.tap()
        savedTitles = ["Container fixture A", "Container fixture B"]

        for title in savedTitles {
            let entry = try XCTUnwrap(scrollToEntry(app, title: title), "\(title) is in the collection")
            XCTAssertEqual(app.staticTexts.matching(identifier: title).count, 1,
                           "\(title) was saved once, not once per experiment in the archive")
            entry.tap()
            XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 20), "\(title) reopens from the collection")
            XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 3),
                           "\(title) is part of the collection now and is not offered for saving again")
            returnToCollection(app)
        }
    }

    // MARK: - helpers

    ///The collection is longer than the screen and only its visible cells exist, so an entry has
    ///to be scrolled to before it can be found at all - a saved experiment lands in its own
    ///category, sorted among all the bundled ones.
    private func scrollToEntry(_ app: XCUIApplication, title: String, swipes: Int = 12) -> XCUIElement? {
        let entry = app.staticTexts[title]
        if entry.exists && entry.isHittable {
            return entry
        }

        let list = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.windows.firstMatch
        //Back to the top first: searching in one direction only would find an entry or not
        //depending on where the step before left the list standing
        for _ in 0..<4 {
            list.swipeDown(velocity: .fast)
            if entry.exists && entry.isHittable {
                return entry
            }
        }
        for _ in 0..<swipes {
            list.swipeUp()
            if entry.exists && entry.isHittable {
                return entry
            }
        }
        return nil
    }

    private func returnToCollection(_ app: XCUIApplication) {
        let back = app.buttons["‹"]
        if back.waitForExistence(timeout: 5) {
            back.tap()
        }
        _ = app.cells.firstMatch.waitForExistence(timeout: 20)
    }

    ///What the experiment's image element would resolve, read through the remote API's /res
    private func resourceOverRemoteAccess(_ src: String) -> Data? {
        guard let url = URL(string: "http://127.0.0.1:\(port)/res?src=\(src)") else { return nil }
        let deadline = Date().addingTimeInterval(20)
        repeat {
            var result: Data?
            let done = expectation(description: "res")
            URLSession.shared.dataTask(with: url) { data, _, _ in
                result = data
                done.fulfill()
            }.resume()
            //XCTWaiter, not wait(for:): the reply not arriving is an ANSWER here, not a test
            //failure. XCTestCase.wait(for:) records one, so a request that simply found no server -
            //which is exactly what several of these checks are looking for - failed the test on a
            //runner where the connection attempt took longer than the wait
            _ = XCTWaiter().wait(for: [done], timeout: 5)
            if let result = result, !result.isEmpty { return result }
        } while Date() < deadline
        return nil
    }

    ///The app's own delete flow: the cell's actions button, Delete, then the confirmation
    private func deleteFromCollection(_ app: XCUIApplication, title: String) {
        let cell = app.cells.containing(.staticText, identifier: title).firstMatch
        guard cell.waitForExistence(timeout: 10) else {
            XCTFail("\(title) is not in the collection - nothing to clean up")
            return
        }

        cell.buttons["Actions"].tap()
        let options = app.sheets.firstMatch
        guard options.waitForExistence(timeout: 5) else {
            XCTFail("the experiment's options did not come up")
            return
        }
        options.buttons["Delete"].tap()

        //The confirmation names the experiment, which is also what tells it apart from the
        //Delete entry of the options sheet it replaces
        let confirmation = app.sheets.buttons["Delete \(title)"]
        guard confirmation.waitForExistence(timeout: 5) else {
            XCTFail("the delete confirmation for \(title) did not come up")
            return
        }
        confirmation.tap()

        let gone = expectation(for: NSPredicate(format: "exists == false"),
                               evaluatedWith: app.staticTexts[title], handler: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed,
                       "\(title) is gone from the collection again")
    }
}
