//
//  ScaleUnitsTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

// phyphox-test: view-scale-units
//What a scale with a unit reference shows under the unit conversion (phyphox-docs views/drawing.md, "Units";
//units.md), checked without rendering on corpus/generated/view-drawing.phyphox: in the experiment's unit the tics
//follow ticStep from min with as many decimals as the step needs; under the imperial setting the Celsius scale shows
//Fahrenheit values at automatically chosen tics within the same geometry (the positions of min and max unchanged,
//converted with the offset); an explicit precision follows the precision rule; a text unit is shown verbatim and
//never converted. Mirrors Android's ScaleUnitsTest, with its 16 px text size for the automatic tic count.
final class ScaleUnitsTests: XCTestCase {
    private var savedSetting: String?

    override func setUpWithError() throws {
        savedSetting = UserDefaults.standard.string(forKey: Units.Setting.key)
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.set(savedSetting, forKey: Units.Setting.key)
    }

    private func setting(_ value: Units.Setting) {
        UserDefaults.standard.set(value.rawValue, forKey: Units.Setting.key)
    }

    ///The rows of the first view, built by the real factory
    private func rows(_ experiment: Experiment) throws -> [UIView] {
        let collection = try XCTUnwrap(experiment.viewDescriptors?.first)
        return ExperimentViewModuleFactory.createViews(collection, resourceFolder: nil).compactMap { $0.view }
    }

    private func loadCorpusFixture() throws -> [UIView] {
        let corpus = try DocsCorpus.directory("generated", notTestedNotice: "scale units")
        return try rows(try ExperimentSerialization.readExperimentFromURL(corpus.appendingPathComponent("view-drawing.phyphox")))
    }

    private func load(_ xml: String) throws -> [UIView] {
        return try rows(try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: InputStream(data: Data(xml.utf8))))
    }

    //The scales of the fixture: the Celsius thermometer in the vertical group, the text-unit scale in the horizontal one
    private func celsius(_ rows: [UIView]) throws -> ExperimentScaleView {
        return try XCTUnwrap(try XCTUnwrap(rows[1] as? ExperimentGroupView).childModules[1] as? ExperimentScaleView)
    }

    private func textUnit(_ rows: [UIView]) throws -> ExperimentScaleView {
        return try XCTUnwrap(try XCTUnwrap(rows[2] as? ExperimentGroupView).childModules[1] as? ExperimentScaleView)
    }

    private func majorTexts(_ scale: ExperimentScaleView, width: Double) -> [String?] {
        return scale.computeTics(width: width, textSize: 16).filter { $0.major }.map { $0.text }
    }

    private func majorValues(_ scale: ExperimentScaleView, width: Double) -> [Double] {
        return scale.computeTics(width: width, textSize: 16).filter { $0.major }.map { $0.value }
    }

    private func minorCount(_ scale: ExperimentScaleView, width: Double) -> Int {
        return scale.computeTics(width: width, textSize: 16).filter { !$0.major }.count
    }

    func testExperimentSettingLaysTheTicsOutFromMinByTicStepWithTheDecimalsOfTheStep() throws {
        setting(.experiment)
        let rows = try loadCorpusFixture()
        let celsius = try celsius(rows)
        XCTAssertTrue(celsius.isConvertible)
        XCTAssertFalse(celsius.isConverted)
        XCTAssertEqual(celsius.labelText, "Temperature (°C)")
        XCTAssertEqual(majorTexts(celsius, width: 400), ["-20", "-10", "0", "10", "20", "30", "40", "50", "60"])
        XCTAssertEqual(minorCount(celsius, width: 400), 8, "one between each pair of major tics")
        let tics = celsius.computeTics(width: 400, textSize: 16)
        XCTAssertEqual(tics[0].fraction, 0, accuracy: 1e-9)
        XCTAssertEqual(tics[8].fraction, 1, accuracy: 1e-9)

        //a step of 0.25 needs two decimals; without a label the unit alone is the label
        let text = try textUnit(rows)
        XCTAssertFalse(text.isConvertible)
        XCTAssertEqual(text.labelText, "m/s²")
        XCTAssertEqual(majorTexts(text, width: 400), ["0.00", "0.25", "0.50", "0.75", "1.00"])
    }

    func testImperialSettingShowsFahrenheitAtAutomaticTicsInTheSameGeometry() throws {
        setting(.imperial)
        let rows = try loadCorpusFixture()
        let celsius = try celsius(rows)
        XCTAssertTrue(celsius.isConverted)
        XCTAssertEqual(celsius.displayUnitId, "degree_fahrenheit")
        XCTAssertEqual(celsius.labelText, "Temperature (°F)")
        //the range keeps its ends: -20 °C at the start, 60 °C at the end of the baseline
        XCTAssertEqual(celsius.effectiveMin, -20)
        XCTAssertEqual(celsius.effectiveMax, 60)
        //-4 °F to 140 °F on a 360 px baseline with 16 px text: four tics at most, so a step of 50 °F; the values are
        //converted with the offset and sit at the positions of their Celsius counterparts
        let tics = celsius.computeTics(width: 400, textSize: 16)
        XCTAssertEqual(majorTexts(celsius, width: 400), ["0", "50", "100"])
        let values = majorValues(celsius, width: 400)
        XCTAssertEqual(values[0], -160.0 / 9.0, accuracy: 1e-9) //0 °F
        XCTAssertEqual(values[1], 10, accuracy: 1e-9) //50 °F
        XCTAssertEqual(values[2], 340.0 / 9.0, accuracy: 1e-9) //100 °F
        for tic in tics {
            XCTAssertEqual(tic.fraction, (tic.value + 20) / 80, accuracy: 1e-9)
        }
        //a text unit is shown verbatim and never converted
        let text = try textUnit(rows)
        XCTAssertFalse(text.isConverted)
        XCTAssertEqual(text.labelText, "m/s²")
        XCTAssertEqual(majorTexts(text, width: 400), ["0.00", "0.25", "0.50", "0.75", "1.00"])
        text.setDisplayUnit("foot")
        XCTAssertFalse(text.isConverted)
    }

    func testMetricSettingLeavesAMetricScaleAlone() throws {
        setting(.metric)
        let rows = try loadCorpusFixture()
        let celsius = try celsius(rows)
        XCTAssertFalse(celsius.isConverted)
        XCTAssertEqual(celsius.labelText, "Temperature (°C)")
        XCTAssertEqual(majorTexts(celsius, width: 400), ["-20", "-10", "0", "10", "20", "30", "40", "50", "60"])
    }

    func testAnExplicitPrecisionFollowsThePrecisionRuleAndTheValueEveryRhythmStaysWithTheExperimentUnit() throws {
        setting(.experiment)
        let rows = try load("""
            <phyphox xmlns="http://phyphox.org/xml" version="1.21" locale="en">
            <title>t</title><category>c</category><description>d</description>
            <data-containers><container size="1">v</container></data-containers>
            <views><view label="v">
            <scale min="0" max="2" unit="@meter" precision="2" ticStep="0.5" valueEvery="2" label="Length" />
            </view></views></phyphox>
            """)
        let length = try XCTUnwrap(rows[0] as? ExperimentScaleView)
        //in the experiment's unit: 0.5 m steps with the authored two decimals, a value at every second tic
        XCTAssertEqual(majorTexts(length, width: 400), ["0.00", nil, "1.00", nil, "2.00"])
        //centimetres: the factor 100 takes the two decimals away, the tics are chosen automatically and every one is labelled
        length.setDisplayUnit("centi_meter")
        XCTAssertEqual(length.labelText, "Length (cm)")
        XCTAssertEqual(majorTexts(length, width: 400), ["0", "50", "100", "150", "200"])
        //feet: a factor of 3.28 keeps the two decimals
        length.setDisplayUnit("foot")
        XCTAssertEqual(majorTexts(length, width: 400), ["0.00", "2.00", "4.00", "6.00"])
        XCTAssertEqual(majorValues(length, width: 400)[1], 2 * 0.3048, accuracy: 1e-9)
        //another quantity is refused
        length.setDisplayUnit("second")
        XCTAssertEqual(length.displayUnitId, "foot")
        length.setDisplayUnit("meter")
        XCTAssertEqual(majorTexts(length, width: 400), ["0.00", nil, "1.00", nil, "2.00"])
    }
}
