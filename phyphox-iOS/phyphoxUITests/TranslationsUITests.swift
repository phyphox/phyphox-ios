//
//  TranslationsUITests.swift
//  phyphoxUITests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest

//The main screens in every language the release ships (test-matrix row translations-ui), checked with
//layout assertions rather than goldens: a screen that fails to come up, text outside the screen, a menu
//that lost entries. A screenshot per language is attached for a human.
final class TranslationsUITests: XCTestCase {
    ///The canonical list (languages.yml), sorted - the order the shards are cut from on both platforms
    private static let allLanguages: [String] = {
        guard let fixtures = ViewBehaviorTests.fixturesDirectory else { return [] }
        let docs = fixtures.deletingLastPathComponent().deletingLastPathComponent()
        guard let text = try? String(contentsOf: docs.appendingPathComponent("languages.yml"), encoding: .utf8) else {
            return []
        }
        var languages: [String] = []
        var inList = false
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("languages:") { inList = true; continue }
            if inList {
                guard trimmed.hasPrefix("- ") else {
                    if !trimmed.isEmpty && !trimmed.hasPrefix("#") { inList = false }
                    continue
                }
                languages.append(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces))
            }
        }
        return languages.sorted()
    }()

    ///What the environment asked for and could not have, reported rather than silently narrowing the sweep
    private static var selectionProblem: String?

    ///The languages this run covers, in the convention shared with Android (row translations-ui):
    ///  PHYPHOX_TEST_LANGUAGE_SHARD=i/n  every n-th language of the sorted list, starting at i
    ///  PHYPHOX_TEST_LANGUAGES=de,fr     exactly these
    ///A code the build does not have is an ERROR, not a skip
    private static let languages: [String] = {
        let all = allLanguages
        let environment = ProcessInfo.processInfo.environment

        if let explicit = environment["PHYPHOX_TEST_LANGUAGES"]?.trimmingCharacters(in: .whitespaces),
           !explicit.isEmpty {
            let requested = explicit.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let unknown = requested.filter { !all.contains($0) }
            guard unknown.isEmpty else {
                selectionProblem = "PHYPHOX_TEST_LANGUAGES asks for \(unknown.joined(separator: ", ")), "
                    + "which this build does not have"
                return []
            }
            return requested
        }

        if let spec = environment["PHYPHOX_TEST_LANGUAGE_SHARD"]?.trimmingCharacters(in: .whitespaces),
           !spec.isEmpty {
            let parts = spec.components(separatedBy: "/")
            guard parts.count == 2, let index = Int(parts[0]), let count = Int(parts[1]),
                  count > 0, index >= 1, index <= count else {
                selectionProblem = "PHYPHOX_TEST_LANGUAGE_SHARD must be i/n with 1 <= i <= n, got \(spec)"
                return []
            }
            //Round robin over the sorted list, so the shards are of equal size
            return all.enumerated().filter { $0.offset % count == index - 1 }.map { $0.element }
        }

        return all
    }()

    private func launch(language: String, arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        //The region stays en_US so only the language changes
        app.launchArguments = arguments + ["-AppleLanguages", "(\(language))", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    ///The last button of the screen (the actions menu), resolved against a fresh hierarchy right before use
    private func lastButton(of app: XCUIApplication) -> XCUIElement? {
        for _ in 0..<5 {
            let count = app.buttons.count
            if count > 0 {
                let candidate = app.buttons.element(boundBy: count - 1)
                if candidate.exists && candidate.isHittable {
                    return candidate
                }
            }
            _ = app.buttons.firstMatch.waitForExistence(timeout: 1)
        }
        return nil
    }

    ///Text that ends up outside the screen is the regression a long translation causes
    private func textOutsideTheScreen(_ app: XCUIApplication) -> [String] {
        //One snapshot of the whole hierarchy: the screen is live (a running graph relabels its tics), and elements
        //resolved by index against a hierarchy that changes underneath fail with "no matches for element at index"
        guard let root = try? app.snapshot() else { return [] }
        let window = root.children.first(where: { $0.elementType == .window })?.frame ?? root.frame
        guard window.width > 0 else { return [] }
        var texts: [XCUIElementSnapshot] = []
        func collect(_ node: XCUIElementSnapshot) {
            if node.elementType == .staticText {
                texts.append(node)
            }
            node.children.forEach(collect)
        }
        collect(root)
        var offenders: [String] = []
        for text in texts.prefix(80) where !text.label.isEmpty {
            let frame = text.frame
            guard frame.width > 0, frame.height > 0 else { continue }
            if frame.minX < -1 || frame.maxX > window.maxX + 1 {
                offenders.append("\(text.label.prefix(40)) at \(frame)")
            }
        }
        return offenders
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // phyphox-test: translations-ui
    func testEveryLanguageRendersTheMainScreens() throws {
        let languages = TranslationsUITests.languages
        if let problem = TranslationsUITests.selectionProblem {
            XCTFail(problem)
            return
        }
        guard !languages.isEmpty else {
            throw XCTSkip("phyphox-docs is not checked out next to this repository - languages not tested")
        }
        print("translations-ui: \(languages.count) of \(TranslationsUITests.allLanguages.count) languages: "
              + languages.joined(separator: ", "))

        for language in languages {
            //One launch per language, straight into an experiment, then back out to the collection
            let app = launch(language: language,
                             arguments: ["-phyphoxUrl", "phyphox://asset=tone_generator.phyphox",
                                         "-phyphoxAutoConfirm"])
            XCTAssertTrue(app.buttons.element(boundBy: 0).waitForExistence(timeout: 25),
                          "the experiment screen does not come up in \(language)")
            var offenders = textOutsideTheScreen(app)
            XCTAssertTrue(offenders.isEmpty,
                          "text outside the screen on the experiment screen in \(language): \(offenders.prefix(3))")
            attachScreenshot(app, name: "experiment-\(language)")

            //The actions menu keeps all six entries whatever their translation. Its label is translated,
            //so it is addressed by position, resolved right before the tap (the count can go stale)
            if let actions = lastButton(of: app) {
                actions.tap()
            } else {
                XCTFail("the experiment screen shows no actions button in \(language)")
            }
            if app.sheets.firstMatch.waitForExistence(timeout: 5) {
                let entries = app.sheets.buttons.count
                XCTAssertGreaterThanOrEqual(entries, 6,
                                            "the actions menu lost entries in \(language): \(entries)")
                attachScreenshot(app, name: "menu-\(language)")
                //Dismiss it again: the cancel entry is the last one whatever it is called
                app.sheets.buttons.element(boundBy: entries - 1).tap()
            }

            app.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 20),
                          "the collection does not come up in \(language)")
            XCTAssertGreaterThan(app.staticTexts.count, 5, "the collection is empty in \(language)")
            offenders = textOutsideTheScreen(app)
            XCTAssertTrue(offenders.isEmpty,
                          "text outside the screen in the collection in \(language): \(offenders.prefix(3))")
            attachScreenshot(app, name: "collection-\(language)")

            app.terminate()
        }
    }
}
