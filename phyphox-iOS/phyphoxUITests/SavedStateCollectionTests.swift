//
//  SavedStateCollectionTests.swift
//  phyphoxUITests
//
//  Created by Sebastian Staacks on 05.10.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest

//The saved-state flow in the collection (test-matrix row saved-state-collection): a state saved from the experiment menu is
//listed under "Saved experiment states" with its title, reopens with its data, is renamed (only meta/state.csv changes),
//shared as a zip that is itself a loadable state, and deleted. The fixture state of phyphox-docs stands in for a
//measurement: it holds data without needing a sensor the simulator lacks. What the screen cannot show - which files a
//rename touched, the zip the share sheet holds - the runner reads from the app's data container, which it can on the
//simulator because both share the device's file system. Saved entries outlive the test, so each is deleted again.
final class SavedStateCollectionTests: XCTestCase {
    private let port = 8086
    private static let bundle = "de.rwth-aachen.physics.phyphox"
    private static let category = "Saved experiment states"
    private static let experimentTitle = "Container fixture saved state"
    ///Everything this suite can leave behind in the collection
    private static let titles = ["UI saved state", "UI saved state renamed", "UI shared state"]
    private var copies: [URL] = []

    private var base: String { "http://127.0.0.1:\(port)" }

    override func tearDownWithError() throws {
        let app = XCUIApplication()
        if app.state != .runningForeground {
            app.launchArguments = ["-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
            app.launch()
        }
        dismissSheets(app)
        returnToCollection(app)
        for title in SavedStateCollectionTests.titles where scrollToEntry(app, title: title, swipes: 8) != nil {
            deleteFromCollection(app, title: title)
        }
        //A state saved under a mangled title would survive the deletion by title: sweep the folder for anything of ours
        if let container = SavedStateCollectionTests.appContainer {
            let states = container.appendingPathComponent("Documents/Saved-States", isDirectory: true)
            for folder in (try? FileManager.default.contentsOfDirectory(at: states, includingPropertiesForKeys: nil)) ?? []
            where (try? String(contentsOf: folder.appendingPathComponent("meta/state.csv"), encoding: .utf8))?.contains("\"title\",\"UI s") == true {
                try? FileManager.default.removeItem(at: folder)
            }
        }
        for copy in copies {
            try? FileManager.default.removeItem(at: copy)
        }
        copies = []
        try super.tearDownWithError()
    }

    // MARK: - launching

    private func fixtureState() throws -> URL {
        guard let fixtures = ViewBehaviorTests.fixturesDirectory else {
            throw XCTSkip("phyphox-docs is not checked out next to this repository")
        }
        let url = fixtures.deletingLastPathComponent().appendingPathComponent("containers/saved-state.zip")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("the phyphox-docs checkout has no fixtures/containers/saved-state.zip")
        }
        return url
    }

    ///Opens a state from outside; no -phyphoxAutoConfirm, so the offer to add it to the collection comes up and is declined
    private func launch(_ state: URL) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-phyphoxUrl", state.absoluteString,
                               "-phyphoxRemote", "-phyphoxRemotePort", String(port),
                               "-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
        app.launch()

        let offer = app.alerts.firstMatch
        XCTAssertTrue(offer.waitForExistence(timeout: 30), "a state opened from outside is offered for the collection like any external experiment")
        XCTAssertTrue(offer.buttons["Save to collection"].exists)
        offer.buttons["Cancel"].tap()
        XCTAssertTrue(waitForAPI(seconds: 20), "the state did not open or the remote API did not come up")
        return app
    }

    // MARK: - the remote API as the oracle for the data

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

    ///The buffer's values; NaN and the infinities come through the JSON as null
    private func buffer(_ name: String) -> [Double?] {
        guard let json = get("/get?\(name)=full"),
              let buffers = json["buffer"] as? [String: Any],
              let entry = buffers[name] as? [String: Any],
              let values = entry["buffer"] as? [Any] else { return [] }
        return values.map { ($0 as? NSNumber)?.doubleValue }
    }

    private func assertFixtureData(_ what: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(buffer("t"), [0, 0.5, 1, 1.5], "\(what): t", file: file, line: line)
        XCTAssertEqual(buffer("calibration"), [9.81], "\(what): the static buffer", file: file, line: line)
        let x = buffer("x")
        XCTAssertEqual(x.count, 4, "\(what): x", file: file, line: line)
        XCTAssertEqual(x.first ?? nil, 1, "\(what): x", file: file, line: line)
        XCTAssertEqual(x.count > 2 ? x[2] : nil, -2.5, "\(what): x", file: file, line: line)
    }

    // MARK: - the app's files

    ///The app's data container on this simulator: the runner's own container is a sibling, and the container metadata names
    ///the bundle. nil when the layout is not what this expects, which skips the file-level assertions
    private static let appContainer: URL? = {
        let applications = URL(fileURLWithPath: NSHomeDirectory()).deletingLastPathComponent()
        guard let candidates = try? FileManager.default.contentsOfDirectory(at: applications, includingPropertiesForKeys: nil) else {
            return nil
        }
        for candidate in candidates {
            let metadata = candidate.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            guard let data = try? Data(contentsOf: metadata),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  plist["MCMMetadataIdentifier"] as? String == bundle else { continue }
            return candidate
        }
        return nil
    }()

    private func appContainer() throws -> URL {
        guard let container = SavedStateCollectionTests.appContainer else {
            throw XCTSkip("the app's data container was not found next to the runner's - the file-level assertions need the simulator layout")
        }
        return container
    }

    ///The saved-state folder in the collection whose meta/state.csv carries the title
    private func stateFolder(titled title: String) throws -> URL {
        let states = try appContainer().appendingPathComponent("Documents/Saved-States", isDirectory: true)
        let folders = try FileManager.default.contentsOfDirectory(at: states, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "phystate" }
        let matching = folders.filter {
            (try? String(contentsOf: $0.appendingPathComponent("meta/state.csv"), encoding: .utf8))?.contains("\"title\",\"\(title)\"") == true
        }
        XCTAssertEqual(matching.count, 1, "one folder in Saved-States holds the state \(title): \(folders.map { $0.lastPathComponent })")
        return try XCTUnwrap(matching.first)
    }

    private func tree(of folder: URL) throws -> [String: Data] {
        var files: [String: Data] = [:]
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey]))
        for case let url as URL in enumerator where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            files[String(url.standardizedFileURL.path.dropFirst(folder.standardizedFileURL.path.count + 1))] = try Data(contentsOf: url)
        }
        return files
    }

    // MARK: - the interactions

    ///Actions > Save experiment state, the title typed over the suggested file name, "To collection", the confirmation
    private func saveState(_ app: XCUIApplication, title: String) {
        app.buttons["Actions"].tap()
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "the actions sheet")
        sheet.buttons["Save experiment state"].tap()

        let dialog = app.alerts.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 5), "the save-state dialog")
        replaceText(of: dialog.textFields.firstMatch, with: title, in: app)
        dialog.buttons["To collection"].tap()

        let confirmation = app.alerts.firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 20), "the state is confirmed saved")
        XCTAssertTrue(confirmation.staticTexts["State has been saved to your collection."].exists)
        confirmation.buttons["OK"].tap()
    }

    ///Clears the field with the delete key from its right edge, twice: the first pass takes what is left of the caret
    ///(a text that overflows the field puts the caret mid-text), the second the rest, which fits by then. The edit menu's
    ///"Select All" is too transient inside an alert, and the keyboard ignores forward delete
    private func replaceText(of field: XCUIElement, with text: String, in app: XCUIApplication) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the text field is on screen")
        let original = (field.value as? String)?.count ?? 0
        for _ in 0..<2 {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
            if let current = field.value as? String, !current.isEmpty {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: min(current.count, original)))
            }
        }
        field.typeText(text)
    }

    ///The cell's actions button, then one of its entries
    private func cellAction(_ app: XCUIApplication, title: String, action: String) {
        let cell = app.cells.containing(.staticText, identifier: title).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "\(title) is in the collection")
        cell.buttons["Actions"].tap()
        let options = app.sheets.firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 5), "the entry's options")
        options.buttons[action].tap()
    }

    ///Only visible cells exist, so an entry has to be scrolled to; a state lands in its own category at the end
    private func scrollToEntry(_ app: XCUIApplication, title: String, swipes: Int = 12) -> XCUIElement? {
        let entry = app.staticTexts[title]
        if entry.exists && entry.isHittable {
            return entry
        }
        let list = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.windows.firstMatch
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

    ///A share sheet or an alert left open would swallow the next tap
    private func dismissSheets(_ app: XCUIApplication) {
        if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
        }
        if app.alerts.firstMatch.exists, app.alerts.firstMatch.buttons["Cancel"].exists {
            app.alerts.firstMatch.buttons["Cancel"].tap()
        }
        if app.sheets.firstMatch.exists, app.sheets.firstMatch.buttons["Cancel"].exists {
            app.sheets.firstMatch.buttons["Cancel"].tap()
        }
    }

    ///The app's own delete flow: the cell's actions button, Delete, then the confirmation naming the entry
    private func deleteFromCollection(_ app: XCUIApplication, title: String) {
        cellAction(app, title: title, action: "Delete")
        let confirmation = app.sheets.buttons["Delete \(title)"]
        guard confirmation.waitForExistence(timeout: 5) else {
            XCTFail("the delete confirmation for \(title) did not come up")
            return
        }
        confirmation.tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts[title], handler: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "\(title) is gone from the collection again")
    }

    // MARK: - the tests

    // phyphox-test: saved-state-collection
    func testSavingListingReopeningRenamingAndDeletingAState() throws {
        let app = launch(try fixtureState())
        assertFixtureData("the fixture state opened from outside")

        saveState(app, title: "UI saved state")
        returnToCollection(app)

        //Listed under the state category with the given title, the experiment's title as the subtitle
        let entry = try XCTUnwrap(scrollToEntry(app, title: "UI saved state"), "the collection gained the state")
        XCTAssertTrue(app.staticTexts[SavedStateCollectionTests.category].exists, "under \(SavedStateCollectionTests.category)")
        let cell = app.cells.containing(.staticText, identifier: "UI saved state").firstMatch
        XCTAssertTrue(cell.staticTexts[SavedStateCollectionTests.experimentTitle].exists, "the experiment's own title is the subtitle")

        //Stored as the container tree, not as a legacy file
        if let folder = try? stateFolder(titled: "UI saved state") {
            let files = try tree(of: folder)
            XCTAssertEqual(Set(files.keys), ["experiment.phyphox", "res/pic.png", "data/index.csv", "data/t.bin", "data/x.bin",
                                             "data/calibration.bin", "data/empty.bin", "data/max_x__m_s__.bin",
                                             "meta/device.csv", "meta/time.csv", "meta/state.csv"])
        }

        //Reopens with its data; the state's title heads the page
        entry.tap()
        XCTAssertTrue(app.navigationBars["UI saved state"].waitForExistence(timeout: 20), "the state opens from the collection")
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 3), "and is not offered for the collection, it is in it")
        XCTAssertTrue(waitForAPI(seconds: 20), "the remote API is up for the reopened state")
        assertFixtureData("the state reopened from the collection")
        returnToCollection(app)

        //Renaming rewrites meta/state.csv and nothing else
        let before = try? tree(of: try stateFolder(titled: "UI saved state"))
        cellAction(app, title: "UI saved state", action: "Rename")
        let rename = app.alerts.firstMatch
        XCTAssertTrue(rename.waitForExistence(timeout: 5), "the rename dialog")
        replaceText(of: rename.textFields.firstMatch, with: "UI saved state renamed", in: app)
        rename.buttons["Rename"].tap()
        XCTAssertNotNil(scrollToEntry(app, title: "UI saved state renamed"), "the list shows the new title")
        XCTAssertFalse(app.staticTexts["UI saved state"].exists, "and not the old one")
        if let before = before {
            let after = try tree(of: try stateFolder(titled: "UI saved state renamed"))
            XCTAssertEqual(Set(before.keys), Set(after.keys))
            for (entry, data) in before where entry != "meta/state.csv" {
                XCTAssertEqual(after[entry], data, "\(entry) is untouched by the rename")
            }
            XCTAssertNotEqual(after["meta/state.csv"], before["meta/state.csv"])
        }

        //Deleting removes the whole folder, resources included
        deleteFromCollection(app, title: "UI saved state renamed")
        if let container = SavedStateCollectionTests.appContainer {
            let states = container.appendingPathComponent("Documents/Saved-States", isDirectory: true)
            let leftovers = ((try? FileManager.default.contentsOfDirectory(at: states, includingPropertiesForKeys: nil)) ?? []).filter {
                (try? String(contentsOf: $0.appendingPathComponent("meta/state.csv"), encoding: .utf8))?.contains("UI saved state") == true
            }
            XCTAssertEqual(leftovers, [], "nothing of the state stays on disk")
        }
    }

    // phyphox-test: saved-state-collection
    func testASharedStateIsAZipThatLoadsAsAState() throws {
        let app = launch(try fixtureState())
        saveState(app, title: "UI shared state")
        returnToCollection(app)

        //Share builds <title>.zip in the app's temporary directory before the sheet comes up
        let container = try appContainer()
        let tmp = container.appendingPathComponent("tmp", isDirectory: true)
        let zipName = "UI shared state.zip"
        try? FileManager.default.removeItem(at: tmp.appendingPathComponent(zipName))
        cellAction(app, title: "UI shared state", action: "Share")

        let shared = tmp.appendingPathComponent(zipName)
        let written = expectation(for: NSPredicate { _, _ in FileManager.default.fileExists(atPath: shared.path) }, evaluatedWith: nil, handler: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [written], timeout: 20), .completed, "the share writes \(zipName)")
        //A copy of our own: the app deletes the file when the sheet goes
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("shared-state-\(UUID().uuidString).zip")
        try FileManager.default.copyItem(at: shared, to: copy)
        copies.append(copy)
        XCTAssertEqual(Array(try Data(contentsOf: copy).prefix(2)), [0x50, 0x4b], "a zip")

        //The zip opens as a state: offered for the collection like the fixture was, titled as saved, data intact
        app.terminate()
        let again = launch(copy)
        XCTAssertTrue(again.navigationBars["UI shared state"].waitForExistence(timeout: 20), "the shared zip opens as the state")
        assertFixtureData("the shared state")
        returnToCollection(again)
    }
}
