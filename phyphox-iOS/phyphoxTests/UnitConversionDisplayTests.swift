//
//  UnitConversionDisplayTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

// phyphox-test: unit-conversion-display
//What the elements DISPLAY follows the unit conversion (phyphox-docs docs/file-format/units.md, "Conversion in the
//app"), checked on corpus/generated/unit-references.phyphox under each Unit system setting and after the switch the
//unit dialog makes: the value's number and unit with the precision rule, the affine temperature, the edit field's
//value, unit and limits with a typed value converted back, the graph's axis titles, tic labels and the picker's
//point, difference and slope read-outs with the composed slope unit; text units, positiveUnit and decimal="false"
//stay untouched; the deprecated placeholder behaves like the reference; the buffers never change.
//Mirrors Android's UnitConversionDisplayTest; the numbers are this platform's own formatting.
final class UnitConversionDisplayTests: XCTestCase {
    private var savedSetting: String?
    private var window: UIWindow?

    override func setUpWithError() throws {
        savedSetting = UserDefaults.standard.string(forKey: Units.Setting.key)
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.set(savedSetting, forKey: Units.Setting.key)
        window?.isHidden = true
        window = nil
    }

    private func setting(_ value: Units.Setting) {
        UserDefaults.standard.set(value.rawValue, forKey: Units.Setting.key)
    }

    private struct Loaded {
        let experiment: Experiment
        let views: [UIView]

        func element<T>(_ index: Int, _ type: T.Type) throws -> T {
            return try XCTUnwrap(views[index] as? T, "element \(index) is a \(T.self)")
        }

        var buffers: [Double?] {
            return ["distance", "temperature", "length"].map { experiment.buffers[$0]?.last }
        }
    }

    private func load(_ experiment: Experiment) throws -> Loaded {
        let collection = try XCTUnwrap(experiment.viewDescriptors?.first)
        let modules = ExperimentViewModuleFactory.createViews(collection, resourceFolder: nil)
        return Loaded(experiment: experiment, views: modules.compactMap { $0.view })
    }

    private func loadCorpusFixture() throws -> Loaded {
        let corpus = try DocsCorpus.directory("generated", notTestedNotice: "unit conversion")
        return try load(try ExperimentSerialization.readExperimentFromURL(corpus.appendingPathComponent("unit-references.phyphox")))
    }

    //Renders the element from its buffer, as the display link does
    private func shown(_ value: ExperimentValueView) -> String {
        value.update()
        return value.displayedText
    }

    private func shown(_ edit: ExperimentEditView) -> String {
        edit.update()
        return edit.textField.text ?? ""
    }

    private func type(_ text: String, into edit: ExperimentEditView) {
        edit.textField.text = text
        edit.textFieldChanged()
        edit.textFieldDidEndEditing(edit.textField)
    }

    //Runs the graph's data update for the given fixed range and returns the tic labels of the frame, x then y
    private func ticLabels(of graph: ExperimentGraphView, x: (Double, Double), y: (Double, Double)) -> (x: [String], y: [String]) {
        graph.frame = CGRect(x: 0, y: 0, width: 390, height: 300)
        graph.layoutIfNeeded()
        graph.zoomManager.applyExternalZoom(x: (x.0, x.1), y: (y.0, y.1))
        graph.graphRenderer.gridView.grid = nil
        graph.setNeedsUpdate()
        graph.dataManager.performUpdate()
        let deadline = Date().addingTimeInterval(5)
        while graph.graphRenderer.gridView.grid == nil && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        graph.graphRenderer.gridView.layoutIfNeeded()
        let labels = graph.graphRenderer.gridView.subviews.compactMap { ($0 as? UILabel)?.text }
        let xCount = graph.graphRenderer.gridView.grid?.xGridLines.count ?? 0
        return (Array(labels.prefix(xCount)), Array(labels.dropFirst(xCount)))
    }

    private func markerLabels(of graph: ExperimentGraphView) -> GraphMarkerLabels {
        return GraphMarkerLabels(descriptor: graph.descriptor, logX: false, logY: false, logZ: false, hasZData: false, displayUnits: graph.displayUnits)
    }

    func testExperimentSettingShowsTheUnitsAsTheFileNamesThem() throws {
        setting(.experiment)
        let loaded = try loadCorpusFixture()
        let before = loaded.buffers
        XCTAssertEqual(shown(try loaded.element(0, ExperimentValueView.self)), "150.0 cm")
        XCTAssertEqual(shown(try loaded.element(1, ExperimentValueView.self)), "21.5 °C")
        let jerk = try loaded.element(2, ExperimentValueView.self)
        XCTAssertFalse(jerk.descriptor.isConvertible)
        XCTAssertEqual(jerk.descriptor.unit, Unit.text("m/s³"))
        let length = try loaded.element(3, ExperimentEditView.self)
        XCTAssertEqual(shown(length), "0.5")
        XCTAssertEqual(length.displayUnitSymbol, "m")
        XCTAssertEqual(length.displayedLimits.min, 0.1, accuracy: 1e-9)
        XCTAssertEqual(length.displayedLimits.max, 2.0, accuracy: 1e-9)
        let acceleration = try loaded.element(4, ExperimentGraphView.self)
        XCTAssertEqual(acceleration.layoutManager.xAxisTitle, "t (s)")
        XCTAssertEqual(acceleration.layoutManager.yAxisTitle, "a (m/s²)")
        let map = try loaded.element(6, ExperimentGraphView.self)
        XCTAssertEqual(map.layoutManager.zAxisTitle, "B (µT)")
        XCTAssertEqual(loaded.buffers, before)
    }

    func testImperialSettingConvertsEveryConvertibleElementAndSkipsTheRest() throws {
        setting(.imperial)
        let loaded = try loadCorpusFixture()
        let before = loaded.buffers
        //cm with one decimal shows two in inches (the precision rule)
        XCTAssertEqual(shown(try loaded.element(0, ExperimentValueView.self)), "59.06 in")
        XCTAssertEqual(shown(try loaded.element(1, ExperimentValueView.self)), "70.7 °F")
        XCTAssertNil(try loaded.element(2, ExperimentValueView.self).displayUnitId, "text stays text")
        let length = try loaded.element(3, ExperimentEditView.self)
        XCTAssertEqual(length.displayUnitId, "foot")
        XCTAssertEqual(shown(length), "1.64042")
        XCTAssertEqual(length.displayUnitSymbol, "ft")
        XCTAssertEqual(length.displayedLimits.min, 0.328, accuracy: 1e-3)
        XCTAssertEqual(length.displayedLimits.max, 6.562, accuracy: 1e-3)
        let acceleration = try loaded.element(4, ExperimentGraphView.self)
        XCTAssertEqual(acceleration.layoutManager.xAxisTitle, "t (s)", "a common unit stays")
        XCTAssertEqual(acceleration.layoutManager.yAxisTitle, "a (ft/s²)")
        //the deprecated placeholder behaves exactly like the reference
        let deprecated = try loaded.element(5, ExperimentGraphView.self)
        XCTAssertEqual(deprecated.descriptor.unitIdX, "second")
        XCTAssertEqual(deprecated.layoutManager.yAxisTitle, "a (ft/s²)")
        let map = try loaded.element(6, ExperimentGraphView.self)
        XCTAssertEqual(map.layoutManager.xAxisTitle, "x (in)")
        XCTAssertEqual(map.layoutManager.zAxisTitle, "B (µT)", "no counterpart")
        XCTAssertEqual(loaded.buffers, before)
    }

    func testMetricSettingLeavesMetricUnitsAlone() throws {
        setting(.metric)
        let loaded = try loadCorpusFixture()
        XCTAssertEqual(shown(try loaded.element(0, ExperimentValueView.self)), "150.0 cm")
        XCTAssertEqual(shown(try loaded.element(1, ExperimentValueView.self)), "21.5 °C")
        XCTAssertEqual(try loaded.element(4, ExperimentGraphView.self).layoutManager.yAxisTitle, "a (m/s²)")
    }

    func testASwitchedUnitChangesWhatTheElementShowsButNotItsData() throws {
        setting(.experiment)
        let loaded = try loadCorpusFixture()
        let before = loaded.buffers

        let distance = try loaded.element(0, ExperimentValueView.self)
        distance.setDisplayUnit("meter") //what the dialog does
        XCTAssertEqual(shown(distance), "1.500 m")
        distance.setDisplayUnit("inch")
        XCTAssertEqual(shown(distance), "59.06 in")
        distance.setDisplayUnit("second") //another quantity is refused
        XCTAssertEqual(shown(distance), "59.06 in")

        let temperature = try loaded.element(1, ExperimentValueView.self)
        temperature.setDisplayUnit("kelvin")
        //294.65 is a tie of the decimal form; the binary value is just below it, so the platform's formatter shows 294.6
        //(Android's Java formatter shows 294.7) - a difference of number formatting, not of the conversion
        XCTAssertEqual(shown(temperature), "294.6 K")
        temperature.setDisplayUnit("degree_fahrenheit")
        XCTAssertEqual(shown(temperature), "70.7 °F")

        let length = try loaded.element(3, ExperimentEditView.self)
        length.setDisplayUnit("foot")
        XCTAssertEqual(shown(length), "1.64042")
        XCTAssertEqual(length.displayUnitSymbol, "ft")
        //a typed value arrives in the buffer converted back
        type("1", into: length)
        XCTAssertEqual(try XCTUnwrap(loaded.experiment.buffers["length"]?.last), 0.3048, accuracy: 1e-9)
        //text typed but not yet committed is dropped by a unit switch; the field shows the current value converted
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        window.addSubview(length)
        window.makeKeyAndVisible()
        self.window = window
        XCTAssertTrue(length.textField.becomeFirstResponder(), "the field takes the keyboard")
        length.textField.text = "7"
        length.textFieldChanged()
        length.setDisplayUnit("centi_meter")
        XCTAssertEqual(length.textField.text, "30.48")
        XCTAssertEqual(try XCTUnwrap(loaded.experiment.buffers["length"]?.last), 0.3048, accuracy: 1e-9)
        //the limits are checked in buffer units: 10 m typed as 1000 cm is clamped to max 2.0
        type("1000", into: length)
        XCTAssertEqual(try XCTUnwrap(loaded.experiment.buffers["length"]?.last), 2.0, accuracy: 1e-9)
        loaded.experiment.buffers["length"]?.replaceValues([try XCTUnwrap(before[2])])

        let acceleration = try loaded.element(4, ExperimentGraphView.self)
        loaded.experiment.buffers["t"]?.replaceValues([0, 1, 2, 3])
        loaded.experiment.buffers["a"]?.replaceValues([0, 2, 4, 6])
        XCTAssertEqual(ticLabels(of: acceleration, x: (0, 10), y: (0, 10)).y, ["0", "2", "4", "6", "8"])
        //the picker: points and their difference in s and m/s², the slope in unitYperX
        let formatter = GraphMarkerLabels.makeFormatter()
        XCTAssertEqual(markerLabels(of: acceleration).singlePoint(x: 1, y: 2, z: .nan, formatter: formatter), "Point\n    1.000 s\n    2.000 m/s²")
        XCTAssertEqual(markerLabels(of: acceleration).difference(x1: 1, x2: 3, y1: 2, y2: 6, z1: .nan, z2: .nan, formatter: formatter), "Difference\n    2.000 s\n    4.000 m/s²\nSlope\n    2.000 m/s")

        acceleration.setDisplayUnit(axis: 1, id: "foot_per_square_second")
        XCTAssertEqual(acceleration.displayUnitIds[1], "foot_per_square_second")
        XCTAssertEqual(acceleration.layoutManager.yAxisTitle, "a (ft/s²)")
        XCTAssertEqual(markerLabels(of: acceleration).singlePoint(x: 1, y: 2, z: .nan, formatter: formatter), "Point\n    1.000 s\n    6.5616798 ft/s²")
        XCTAssertEqual(ticLabels(of: acceleration, x: (0, 10), y: (0, 10)).y, ["0", "10", "20", "30"])
        //the slope is scaled by the ratio of the axis scales and its unit composed from the display symbols
        XCTAssertEqual(markerLabels(of: acceleration).difference(x1: 1, x2: 3, y1: 2, y2: 6, z1: .nan, z2: .nan, formatter: formatter), "Difference\n    2.000 s\n    13.12336 ft/s²\nSlope\n    6.5616798 ft/s² / s")
        acceleration.setDisplayUnit(axis: 0, id: "milli_second")
        XCTAssertEqual(acceleration.layoutManager.xAxisTitle, "t (ms)")
        XCTAssertEqual(markerLabels(of: acceleration).difference(x1: 1, x2: 3, y1: 2, y2: 6, z1: .nan, z2: .nan, formatter: formatter), "Difference\n    2000 ms\n    13.12336 ft/s²\nSlope\n    0.0065616798 ft/s² / ms")
        XCTAssertEqual(markerLabels(of: acceleration).linearFit(slope: 2, intercept: 1, formatter: formatter), "Linear fit: y = a x + b\na = 0.0065616798 ft/s² / ms\nb = 3.2808399 ft/s²")

        let deprecated = try loaded.element(5, ExperimentGraphView.self)
        deprecated.setDisplayUnit(axis: 0, id: "milli_second")
        XCTAssertEqual(deprecated.layoutManager.xAxisTitle, "t (ms)")

        loaded.experiment.buffers["t"]?.replaceValues([])
        loaded.experiment.buffers["a"]?.replaceValues([])
        XCTAssertEqual(loaded.buffers, before)
    }

    func testTheAffineTemperatureAxisConvertsPositionsWithTheOffsetAndDifferencesWithTheScale() throws {
        setting(.experiment)
        let xml = """
        <phyphox xmlns="http://phyphox.org/xml" version="1.21" locale="en">
            <title>t</title><category>c</category><description>d</description>
            <data-containers><container size="10" init="0,1,2">t</container><container size="10" init="20,21,22">T</container></data-containers>
            <views><view label="v">
                <graph label="Temperature" labelX="t" unitX="@second" labelY="T" unitY="@degree_celsius"><input axis="x">t</input><input axis="y">T</input></graph>
            </view></views>
        </phyphox>
        """
        let loaded = try load(try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: InputStream(data: Data(xml.utf8))))
        let graph = try loaded.element(0, ExperimentGraphView.self)
        graph.setDisplayUnit(axis: 1, id: "degree_fahrenheit")
        XCTAssertEqual(graph.layoutManager.yAxisTitle, "T (°F)")
        let formatter = GraphMarkerLabels.makeFormatter()
        XCTAssertEqual(markerLabels(of: graph).singlePoint(x: 1, y: 20, z: .nan, formatter: formatter), "Point\n    1.000 s\n    68.00 °F")
        XCTAssertEqual(markerLabels(of: graph).difference(x1: 0, x2: 2, y1: 20, y2: 22, z1: .nan, z2: .nan, formatter: formatter), "Difference\n    2.000 s\n    3.600 °F\nSlope\n    1.800 °F / s")
        //fixed 0..100 °C is ticked as 32..212 °F at nice Fahrenheit numbers
        XCTAssertEqual(ticLabels(of: graph, x: (0, 2), y: (0, 100)).y, ["50", "100", "150", "200"])
        graph.setDisplayUnit(axis: 1, id: "kelvin")
        XCTAssertEqual(markerLabels(of: graph).singlePoint(x: 1, y: 20, z: .nan, formatter: formatter), "Point\n    1.000 s\n    293.15 K")
    }

    func testTheExclusionsOfferNoConversion() throws {
        setting(.imperial)
        let xml = """
        <phyphox xmlns="http://phyphox.org/xml" version="1.21" locale="en">
            <title>t</title><category>c</category><description>d</description>
            <data-containers><container size="1" init="1.5">v</container><container size="1" init="3">n</container><container size="10" init="0,1,2">t</container></data-containers>
            <views><view label="v">
                <value label="Direction" unit="@meter" positiveUnit="N" negativeUnit="S"><input>v</input></value>
                <edit label="Count" unit="@meter" decimal="false"><output>n</output></edit>
                <value label="Angle" unit="@degree" format="degree-minutes"><input>v</input></value>
                <value label="Level" unit="@decibel"><input>v</input></value>
                <graph label="Clock" labelX="t" unitX="@second" labelY="v" unitY="@meter" timeOnX="true" systemTime="true"><input axis="x">t</input><input axis="y">t</input></graph>
            </view></views>
        </phyphox>
        """
        let loaded = try load(try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: InputStream(data: Data(xml.utf8))))
        let direction = try loaded.element(0, ExperimentValueView.self)
        XCTAssertFalse(direction.descriptor.isConvertible)
        XCTAssertEqual(direction.displayUnitId, "meter")
        XCTAssertEqual(shown(direction), "1.50 N")
        let count = try loaded.element(1, ExperimentEditView.self)
        XCTAssertFalse(count.descriptor.isConvertible)
        XCTAssertEqual(shown(count), "3")
        XCTAssertEqual(count.displayUnitSymbol, "m")
        XCTAssertFalse(try loaded.element(2, ExperimentValueView.self).descriptor.isConvertible)
        let level = try loaded.element(3, ExperimentValueView.self)
        XCTAssertFalse(level.descriptor.isConvertible)
        XCTAssertEqual(shown(level), "1.50 dB")
        //a time axis showing a clock is not converted, the y axis of the same graph is
        let clock = try loaded.element(4, ExperimentGraphView.self)
        XCTAssertFalse(clock.isAxisConvertible(0))
        XCTAssertTrue(clock.isAxisConvertible(1))
        XCTAssertEqual(clock.displayUnitIds[1], "foot")
        XCTAssertEqual(clock.layoutManager.yAxisTitle, "v (ft)")
        clock.systemTime = false
        XCTAssertTrue(clock.isAxisConvertible(0))
        XCTAssertEqual(clock.layoutManager.xAxisTitle, "t (s)")
    }

    func testLinkedZoomMatchesTheQuantityAndConvertsTheRange() throws {
        setting(.experiment)
        let xml = """
        <phyphox xmlns="http://phyphox.org/xml" version="1.21" locale="en">
            <title>t</title><category>c</category><description>d</description>
            <data-containers><container size="10" init="0,1,2">t</container><container size="10" init="0,1,2">a</container></data-containers>
            <views><view label="v">
                <graph label="Seconds" labelX="t" unitX="@second" labelY="a" unitY="@meter_per_square_second"><input axis="x">t</input><input axis="y">a</input></graph>
                <graph label="Milliseconds" labelX="t" unitX="@milli_second" labelY="a" unitY="m/s³"><input axis="x">t</input><input axis="y">a</input></graph>
                <graph label="Text" labelX="t" unitX="s" labelY="a" unitY="m/s³"><input axis="x">t</input><input axis="y">a</input></graph>
            </view></views>
        </phyphox>
        """
        let loaded = try load(try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: InputStream(data: Data(xml.utf8))))
        let seconds = try loaded.element(0, ExperimentGraphView.self)
        let milliseconds = try loaded.element(1, ExperimentGraphView.self)
        let text = try loaded.element(2, ExperimentGraphView.self)
        //a zoom of 1..2 s kept on every graph with the same unit reaches the millisecond axis as 1000..2000
        for graph in [milliseconds, text] {
            graph.applyZoom(modeX: .keep, applyToX: .sameUnit, targetX: nil, unitX: seconds.descriptor.xAxisUnit, modeY: .keep, applyToY: .sameUnit, targetY: nil, unitY: seconds.descriptor.yAxisUnit, zoomMin: GraphPoint2D(x: 1, y: 0), zoomMax: GraphPoint2D(x: 2, y: 5), systemTime: false)
        }
        XCTAssertEqual(milliseconds.zoomManager.currentZoomBounds.min.x, 1000, accuracy: 1e-9)
        XCTAssertEqual(milliseconds.zoomManager.currentZoomBounds.max.x, 2000, accuracy: 1e-9)
        XCTAssertTrue(milliseconds.zoomManager.currentZoomBounds.min.y.isNaN, "the text unit m/s³ does not match m/s²")
        XCTAssertFalse(text.zoomManager.hasCustomZoom, "the text unit s does not match the reference")
        text.applyZoom(modeX: .keep, applyToX: .sameUnit, targetX: nil, unitX: Unit.text("s"), modeY: .none, applyToY: .none, targetY: nil, unitY: nil, zoomMin: GraphPoint2D(x: 1, y: 0), zoomMax: GraphPoint2D(x: 2, y: 5), systemTime: false)
        XCTAssertEqual(text.zoomManager.currentZoomBounds.max.x, 2, accuracy: 1e-9, "text matches by equal text")
    }
}
