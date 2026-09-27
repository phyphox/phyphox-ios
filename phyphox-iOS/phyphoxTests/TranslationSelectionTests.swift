//
//  TranslationSelectionTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

// phyphox-test: translation-block-selection
//Which translation block a file gets (phyphox-docs file-format/index.md, "Block: translations"): the block matching
//the device language best, the base strings otherwise. A missing root locale counts as "en", and a block carrying the
//root's locale stands in for the base strings unless another block rates strictly better. Mirrors Android's
//TranslationSelectionTest; the device language is set through ExperimentTranslationCollection.deviceLocaleOverride.
final class TranslationSelectionTests: XCTestCase {
    private static func file(_ rootAttributes: String, _ translations: String) -> String {
        return "<phyphox version=\"1.13\"" + rootAttributes + ">"
            + "<title>Base title</title><category>Base category</category><description>Base description</description>"
            + "<translations>" + translations + "</translations>"
            + "<data-containers><container size=\"1\">v</container></data-containers>"
            + "<input></input><analysis></analysis>"
            + "<views><view label=\"Base view\"><value label=\"Base label\"><input>v</input></value></view></views>"
            + "</phyphox>"
    }

    private static let germanBlock = "<translation locale=\"de\"><title>Deutscher Titel</title>"
        + "<category>Deutsche Kategorie</category><description>Deutsche Beschreibung</description>"
        + "<string original=\"Base label\">Deutsches Label</string></translation>"

    private static let englishBlock = "<translation locale=\"en\"><title>English title</title>"
        + "<category>English category</category><description>English description</description>"
        + "<string original=\"Base label\">English label</string></translation>"

    override func tearDown() {
        ExperimentTranslationCollection.deviceLocaleOverride = nil
        super.tearDown()
    }

    ///Parses the file as seen by a device running in the given locale
    private func load(_ xml: String, device: String) throws -> Experiment {
        ExperimentTranslationCollection.deviceLocaleOverride = Locale(identifier: device)
        return try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: InputStream(data: Data(xml.utf8)))
    }

    private func label(_ experiment: Experiment) throws -> String {
        return try XCTUnwrap(experiment.viewDescriptors?.first?.views.first).localizedLabel
    }

    private func assertStrings(_ experiment: Experiment, title: String, label expectedLabel: String, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(experiment.localizedTitle, title, file: file, line: line)
        XCTAssertEqual(try label(experiment), expectedLabel, file: file, line: line)
    }

    func testGermanBlockWithoutRootLocaleIsNotAppliedOnNonGermanDevices() throws {
        //en_DE: English in Germany; "en": no region, as an in-app language setting yields
        for device in ["en_US", "en", "en_DE", "fr_FR"] {
            let experiment = try load(Self.file("", Self.germanBlock), device: device)
            XCTAssertEqual(experiment.localizedTitle, "Base title", device)
            XCTAssertEqual(experiment.localizedCategory, "Base category", device)
            XCTAssertEqual(try label(experiment), "Base label", device)
        }
    }

    func testGermanBlockWithoutRootLocaleIsAppliedOnAGermanDevice() throws {
        let experiment = try load(Self.file("", Self.germanBlock), device: "de_DE")
        XCTAssertEqual(experiment.localizedTitle, "Deutscher Titel")
        XCTAssertEqual(experiment.localizedCategory, "Deutsche Kategorie")
        XCTAssertEqual(experiment.localizedDescription, "Deutsche Beschreibung")
        XCTAssertEqual(try label(experiment), "Deutsches Label")
    }

    func testGermanBlockWithEnglishRootLocale() throws {
        for device in ["en_US", "en"] {
            try assertStrings(try load(Self.file(" locale=\"en\"", Self.germanBlock), device: device), title: "Base title", label: "Base label")
        }
        try assertStrings(try load(Self.file(" locale=\"en\"", Self.germanBlock), device: "de_DE"), title: "Deutscher Titel", label: "Deutsches Label")
    }

    func testGermanDeviceGetsTheGermanBlockAheadOfTheEnglishOne() throws {
        try assertStrings(try load(Self.file("", Self.englishBlock + Self.germanBlock), device: "de_DE"), title: "Deutscher Titel", label: "Deutsches Label")
    }

    //Without a root locale the English block stands in for the base strings on any device no other block matches.
    //The bundled light experiment has no base strings at all and relies on this.
    func testEnglishBlockWithoutRootLocaleStandsInForTheBase() throws {
        for device in ["en_US", "fr_FR"] {
            try assertStrings(try load(Self.file("", Self.englishBlock + Self.germanBlock), device: device), title: "English title", label: "English label")
        }
    }

    func testGermanBlockWithGermanRootLocaleStandsInForTheBaseOnAnEnglishDevice() throws {
        try assertStrings(try load(Self.file(" locale=\"de\"", Self.germanBlock), device: "en_US"), title: "Deutscher Titel", label: "Deutsches Label")
    }

    //A better-rated block beats the stand-in, in either order
    func testEnglishBlockBeatsTheStandInWithGermanRootLocale() throws {
        try assertStrings(try load(Self.file(" locale=\"de\"", Self.germanBlock + Self.englishBlock), device: "en_US"), title: "English title", label: "English label")
        try assertStrings(try load(Self.file(" locale=\"de\"", Self.englishBlock + Self.germanBlock), device: "en_US"), title: "English title", label: "English label")
    }

    func testEnglishBlockWithGermanRootLocaleIsAppliedOnAnEnglishDevice() throws {
        try assertStrings(try load(Self.file(" locale=\"de\"", Self.englishBlock), device: "en_US"), title: "English title", label: "English label")
    }

    func testTheBundledLightExperimentGetsItsEnglishTitle() throws {
        let url = try XCTUnwrap(testBundle.url(forResource: "phyphox-experiments", withExtension: nil)).appendingPathComponent("light.phyphox")
        ExperimentTranslationCollection.deviceLocaleOverride = Locale(identifier: "en_US")
        let experiment = try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: XCTUnwrap(InputStream(url: url)))
        XCTAssertEqual(experiment.localizedTitle, "Light")
        XCTAssertEqual(experiment.localizedCategory, "Raw Sensors")
    }
}
