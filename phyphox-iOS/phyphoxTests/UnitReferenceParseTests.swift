//
//  UnitReferenceParseTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

// phyphox-test: unit-reference-parse
//The unit attributes are parsed to logical units (phyphox-docs spec/rules.yml "unit-reference", spec/units.yml,
//docs/file-format/units.md): in a 1.21 file "@meter" is the known unit meter shown with the app's symbol,
//"[[unit_short_meter]]" is the same unit in every version, and a literal "m", an "@meter" in a 1.20 file and an
//unknown "@metre" in a 1.21 file are text, shown verbatim and not convertible. The three corpus files of the rule load.
//Mirrors Android's UnitReferenceParseTest.
final class UnitReferenceParseTests: XCTestCase {
    private func xml(version: String, unit: String) -> String {
        return """
        <phyphox xmlns="http://phyphox.org/xml" version="\(version)" locale="en">
            <title>t</title><category>c</category><description>d</description>
            <data-containers><container size="1" init="1.5">v</container><container size="10">t</container></data-containers>
            <views><view label="v">
                <value label="a" unit="\(unit)"><input>v</input></value>
                <edit label="e" unit="\(unit)"><output>v</output></edit>
                <graph label="g" labelX="x" unitX="\(unit)" labelY="y" unitY="\(unit)" unitYperX="\(unit)"><input axis="x">t</input><input axis="y">t</input></graph>
            </view></views>
        </phyphox>
        """
    }

    private struct Elements {
        let value: ValueViewDescriptor
        let edit: EditViewDescriptor
        let graph: GraphViewDescriptor
    }

    private func load(version: String, unit: String) throws -> Elements {
        let experiment = try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: InputStream(data: Data(xml(version: version, unit: unit).utf8)))
        let views = try XCTUnwrap(experiment.viewDescriptors?.first?.views)
        return Elements(value: try XCTUnwrap(views[0] as? ValueViewDescriptor), edit: try XCTUnwrap(views[1] as? EditViewDescriptor), graph: try XCTUnwrap(views[2] as? GraphViewDescriptor))
    }

    private func assertAll(_ elements: Elements, id: String?, text: String, file: StaticString = #filePath, line: UInt = #line) {
        let expected = id.map { Unit.reference($0) } ?? Unit.text(text)
        XCTAssertEqual(elements.value.unit, expected, "value", file: file, line: line)
        XCTAssertEqual(elements.edit.unit, expected, "edit", file: file, line: line)
        XCTAssertEqual(elements.graph.xAxisUnit, expected, "unitX", file: file, line: line)
        XCTAssertEqual(elements.graph.yAxisUnit, expected, "unitY", file: file, line: line)
    }

    func testAReferenceInA121FileIsTheKnownUnit() throws {
        let elements = try load(version: "1.21", unit: "@meter")
        assertAll(elements, id: "meter", text: "")
        XCTAssertEqual(elements.value.unit.symbol, "m")
        XCTAssertEqual(elements.value.localizedUnit, "m")
        XCTAssertTrue(elements.value.isConvertible)
        XCTAssertTrue(elements.edit.isConvertible)
        XCTAssertEqual(elements.graph.unitIdX, "meter")
        XCTAssertEqual(elements.graph.localizedXUnit, "m")
        XCTAssertEqual(elements.graph.localizedYXUnit, "m")
    }

    func testTheDeprecatedPlaceholderIsTheSameUnitInEveryVersion() throws {
        assertAll(try load(version: "1.21", unit: "[[unit_short_meter]]"), id: "meter", text: "")
        assertAll(try load(version: "1.20", unit: "[[unit_short_meter]]"), id: "meter", text: "")
        assertAll(try load(version: "1.6", unit: "[[unit_short_meter]]"), id: "meter", text: "")
    }

    func testLiteralTextStaysText() throws {
        let elements = try load(version: "1.21", unit: "m")
        assertAll(elements, id: nil, text: "m")
        XCTAssertFalse(elements.value.isConvertible)
        XCTAssertFalse(elements.edit.isConvertible)
        XCTAssertNil(elements.graph.unitIdX)
    }

    func testAReferenceInAnOlderFileIsText() throws {
        assertAll(try load(version: "1.20", unit: "@meter"), id: nil, text: "@meter")
    }

    func testAnUnknownIdIsTextInA121File() throws {
        assertAll(try load(version: "1.21", unit: "@metre"), id: nil, text: "@metre")
        //an unknown placeholder is text through the translation path, as before: on iOS that path resolves a [[...]]
        //placeholder to the string key, so the key is shown (Android shows the placeholder verbatim - a pre-existing
        //difference of the placeholder path, not of unit references)
        assertAll(try load(version: "1.21", unit: "[[unit_short_metre]]"), id: nil, text: "common_unit_short_metre")
    }

    func testTheTableAgreesWithTheSpecification() {
        XCTAssertEqual(Units.all.count, 49)
        XCTAssertEqual(Units.forSetting("meter", .imperial), "foot")
        XCTAssertEqual(Units.forSetting("meter", .metric), "meter")
        XCTAssertEqual(Units.forSetting("foot", .metric), "meter")
        XCTAssertEqual(Units.forSetting("second", .imperial), "second", "a common unit stays")
        XCTAssertEqual(Units.forSetting("nano_meter", .imperial), "nano_meter", "a unit without counterpart stays")
        XCTAssertEqual(Units.convert(1.5, from: "meter", to: "centi_meter"), 150, accuracy: 1e-9)
        XCTAssertEqual(Units.convert(21.5, from: "degree_celsius", to: "degree_fahrenheit"), 70.7, accuracy: 1e-9)
        XCTAssertEqual(Units.convertDifference(10, from: "degree_celsius", to: "degree_fahrenheit"), 18, accuracy: 1e-9)
        XCTAssertEqual(Units.precision(2, factor: 100), 0, "m with 2 decimals -> cm with 0")
        XCTAssertEqual(Units.precision(1, factor: 0.01 / 0.0254), 2, "cm with 1 -> in with 2")
        XCTAssertEqual(Units.precision(0, factor: 0.001 / 0.0254), 2, "mm with 0 -> in with 2")
        XCTAssertEqual(Units.precision(2, factor: 3.6), 2, "m/s with 2 -> km/h with 2")
        XCTAssertEqual(Units.alternatives("meter").map { $0.id }, ["nano_meter", "micro_meter", "milli_meter", "centi_meter", "meter", "kilo_meter", "inch", "foot", "yard", "mile"])
        XCTAssertTrue(Units.alternatives("decibel").isEmpty)
        XCTAssertEqual(UnitDialog.listedUnitIds("second"), ["micro_second", "milli_second", "second", "minute", "hour"])
        XCTAssertEqual(UnitDialog.rowTitle("centi_meter", experimentUnitId: "centi_meter"), "cm (default)")
    }

    func testTheCorpusFilesOfTheRuleLoadAsSpecified() throws {
        let corpus = try DocsCorpus.directory("generated", notTestedNotice: "unit references")
        let references = try ExperimentSerialization.readExperimentFromURL(corpus.appendingPathComponent("unit-references.phyphox"))
        let views = try XCTUnwrap(references.viewDescriptors?.first?.views)
        XCTAssertEqual((views[0] as? ValueViewDescriptor)?.unit.id, "centi_meter")
        XCTAssertEqual((views[2] as? ValueViewDescriptor)?.unit, Unit.text("m/s³"))
        XCTAssertEqual((views[5] as? GraphViewDescriptor)?.unitIdX, "second", "[[unit_short_second]]")

        let old = try ExperimentSerialization.readExperimentFromURL(corpus.appendingPathComponent("unit-reference-old-version.phyphox"))
        XCTAssertEqual((old.viewDescriptors?.first?.views.first as? ValueViewDescriptor)?.unit, Unit.text("@meter"))

        let invalid = try DocsCorpus.directory("invalid", notTestedNotice: "unit references")
        let unknown = try ExperimentSerialization.readExperimentFromURL(invalid.appendingPathComponent("unit-reference-unknown.phyphox"))
        XCTAssertEqual((unknown.viewDescriptors?.first?.views.first as? ValueViewDescriptor)?.unit, Unit.text("@metre"))
    }
}
