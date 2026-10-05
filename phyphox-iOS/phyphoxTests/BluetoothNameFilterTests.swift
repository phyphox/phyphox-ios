//
//  BluetoothNameFilterTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

// phyphox-test: ble-name-regex-match
//Rule ble-name-regex (phyphox-docs, spec/rules.yml): nameRegex has to match the whole device name, case-sensitively,
//name stays a substring test, both have to hold when given, and a pattern that does not compile refuses the file.
//Mirrors Android's BluetoothNameFilterTest.
final class BluetoothNameFilterTests: XCTestCase {

    func testAPatternWithoutMetacharactersIsTheExactName() throws {
        let filter = try BluetoothNameFilter(name: nil, regex: "phyphox:m")
        XCTAssertTrue(filter.matches("phyphox:m"))
        XCTAssertFalse(filter.matches("phyphox:mini"))
        XCTAssertFalse(filter.matches("Xphyphox:m"))
    }

    func testPrefixAndAlternationPatterns() throws {
        let prefix = try BluetoothNameFilter(name: nil, regex: "phyphox:m.*")
        XCTAssertTrue(prefix.matches("phyphox:m"))
        XCTAssertTrue(prefix.matches("phyphox:mini"))
        XCTAssertFalse(prefix.matches("phyphox:e"))

        let alternatives = try BluetoothNameFilter(name: nil, regex: "phyphox:(m|mini)")
        XCTAssertTrue(alternatives.matches("phyphox:m"))
        XCTAssertTrue(alternatives.matches("phyphox:mini"))
        XCTAssertFalse(alternatives.matches("phyphox:max"))

        //The whole name has to match even when an earlier alternative matches a prefix of it (Java's matches())
        XCTAssertTrue(try BluetoothNameFilter(name: nil, regex: "a|ab").matches("ab"))
    }

    func testMatchingIsCaseSensitive() throws {
        XCTAssertFalse(try BluetoothNameFilter(name: nil, regex: "phyphox:m").matches("Phyphox:M"))
        XCTAssertFalse(BluetoothNameFilter(name: "phyphox").matches("Phyphox:m"))
    }

    func testNameStaysASubstringTestAndBothCriteriaHaveToHold() throws {
        XCTAssertTrue(BluetoothNameFilter(name: "phyphox:m").matches("phyphox:mini"))

        let both = try BluetoothNameFilter(name: "mini", regex: "phyphox:(m|mini)")
        XCTAssertTrue(both.matches("phyphox:mini"))
        XCTAssertFalse(both.matches("phyphox:m")) //regex holds, name does not
        XCTAssertFalse(both.matches("mini")) //name holds, regex does not
    }

    func testNoCriterionMatchesEverything() throws {
        for filter in [try BluetoothNameFilter(name: nil, regex: nil), try BluetoothNameFilter(name: "", regex: ""), BluetoothNameFilter.none] {
            XCTAssertTrue(filter.isEmpty)
            XCTAssertTrue(filter.matches("anything"))
        }
        XCTAssertFalse(try BluetoothNameFilter(name: nil, regex: "x").isEmpty)
    }

    func testFiltersWithTheSamePatternsAreEqual() throws {
        XCTAssertEqual(try BluetoothNameFilter(name: "a", regex: "b"), try BluetoothNameFilter(name: "a", regex: "b"))
        XCTAssertNotEqual(BluetoothNameFilter(name: "a"), try BluetoothNameFilter(name: nil, regex: "a"))
        XCTAssertEqual(try BluetoothNameFilter(name: nil, regex: "x").description, "x")
        XCTAssertEqual(BluetoothNameFilter(name: "n").description, "n")
    }

    func testAnInvalidPatternThrowsAtConstruction() {
        XCTAssertThrowsError(try BluetoothNameFilter(name: nil, regex: "phyphox:(m"))
    }

    func testTheCorpusFixtureLoadsWithItsFiltersOnBothBlocks() throws {
        let corpus = try DocsCorpus.directory("generated", notTestedNotice: "bluetooth name regex")
        let experiment = try ExperimentSerialization.readExperimentFromURL(corpus.appendingPathComponent("bluetooth-name-regex.phyphox"))
        XCTAssertEqual(experiment.bluetoothInputs.count, 1)
        XCTAssertEqual(experiment.bluetoothInputs.first?.device.nameFilter, try BluetoothNameFilter(name: nil, regex: "phyphox:m"))
        XCTAssertEqual(experiment.bluetoothOutputs.count, 1)
        XCTAssertEqual(experiment.bluetoothOutputs.first?.device.nameFilter, try BluetoothNameFilter(name: "phyphox", regex: "phyphox:(m|mini)"))
    }

    func testAnInvalidPatternRefusesTheFileOnTheRealLoadingPath() throws {
        let invalid = try DocsCorpus.directory("invalid", notTestedNotice: "bluetooth name regex")
        XCTAssertThrowsError(try ExperimentSerialization.readExperimentFromURL(invalid.appendingPathComponent("bluetooth-name-regex-invalid.phyphox"))) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("nameRegex"), message)
            XCTAssertTrue(message.contains("phyphox:(m"), message)
        }
    }
}
