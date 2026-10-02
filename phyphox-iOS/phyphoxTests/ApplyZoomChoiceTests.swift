//
//  ApplyZoomChoiceTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

// phyphox-test: apply-zoom-choice
//The rules behind "Keep this view?" when a maximized graph is left (ApplyZoomChoice, GraphZoomManager.isZoomed): no
//question when nothing is zoomed, also while a time axis shows system time; the per-axis controls start from the
//emphasised button; a reset of one axis keeps the others' zoom (iOS used to drop a z zoom when x was reset); the axis
//titles show the zoomed range in the display unit, formatted like the tic labels. Mirrors Android's ApplyZoomChoiceTest.
final class ApplyZoomChoiceTests: XCTestCase {
    private var savedSetting: String?

    override func setUpWithError() throws {
        savedSetting = UserDefaults.standard.string(forKey: Units.Setting.key)
        UserDefaults.standard.set(Units.Setting.experiment.rawValue, forKey: Units.Setting.key)
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.set(savedSetting, forKey: Units.Setting.key)
    }

    private func graph(_ graphXML: String) throws -> ExperimentGraphView {
        let xml = """
        <phyphox xmlns="http://phyphox.org/xml" version="1.21" locale="en">
            <title>zoom</title><category>test</category><description>d</description>
            <data-containers>
                <container size="5" init="0,1,2,3,4">t</container>
                <container size="5" init="0,2,1,4,3">a</container>
            </data-containers>
            <views><view label="v">\(graphXML)</view></views>
        </phyphox>
        """
        let experiment = try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: InputStream(data: Data(xml.utf8)))
        let modules = ExperimentViewModuleFactory.createViews(try XCTUnwrap(experiment.viewDescriptors?.first), resourceFolder: nil)
        let graph = try XCTUnwrap(modules.first?.view as? ExperimentGraphView)
        graph.frame = CGRect(x: 0, y: 0, width: 390, height: 300)
        graph.layoutIfNeeded()
        return graph
    }

    private let plain = """
        <graph label="g" labelX="t" unitX="s" labelY="a" unitY="@meter_per_square_second" timeOnX="true">
            <input axis="x">t</input><input axis="y">a</input>
        </graph>
        """

    private let following = """
        <graph label="f" labelX="t" unitX="s" labelY="a" unitY="m/s²" followX="true" partialUpdate="true" scaleMinX="fixed" scaleMaxX="fixed" minX="-2" maxX="0">
            <input axis="x">t</input><input axis="y">a</input>
        </graph>
        """

    func testNoQuestionWhenNothingIsZoomedEvenOnSystemTime() throws {
        let graph = try graph(plain)
        XCTAssertFalse(graph.zoomManager.anyZoomed)
        graph.systemTime = true
        XCTAssertFalse(graph.zoomManager.anyZoomed, "a clock on the time axis is not a zoom")

        graph.zoomManager.applyExternalZoom(x: nil, y: (min: 1, max: 3))
        XCTAssertTrue(graph.zoomManager.anyZoomed)
        XCTAssertFalse(graph.zoomManager.isZoomed(axis: 0))
        XCTAssertTrue(graph.zoomManager.isZoomed(axis: 1))
        XCTAssertFalse(graph.zoomManager.isZoomed(axis: 2))
    }

    func testAFollowingGraphAtRestIsNotZoomed() throws {
        let graph = try graph(following)
        XCTAssertFalse(graph.zoomManager.anyZoomed, "following the configured window is the reset state")
        XCTAssertTrue(graph.zoomManager.isZoomFollows)

        graph.zoomManager.applyExternalZoom(x: (min: 1, max: 3), y: nil)
        XCTAssertTrue(graph.zoomManager.isZoomed(axis: 0))

        //"Keep this section" stops following, a reset goes back to following the configured window
        graph.zoomManager.applyZoomSettings(modeX: .keep, applyToX: .this, modeY: .none, applyToY: .this)
        XCTAssertFalse(graph.zoomManager.isZoomFollows)
        graph.zoomManager.applyZoomSettings(modeX: .reset, applyToX: .this, modeY: .none, applyToY: .this)
        XCTAssertFalse(graph.zoomManager.anyZoomed)
        XCTAssertTrue(graph.zoomManager.isZoomFollows)
        let window = try XCTUnwrap(graph.zoomManager.zoomRange(axis: 0))
        XCTAssertEqual(window.min, -2)
        XCTAssertEqual(window.max, 0)

        //a follow mode toggled off by hand is a zoom
        graph.zoomManager.toggleFollow()
        XCTAssertTrue(graph.zoomManager.isZoomed(axis: 0))
    }

    func testPerAxisControlsStartFromTheEmphasisedButton() {
        XCTAssertEqual(ApplyZoomChoice.defaultAction(previouslyKept: false), .reset)
        XCTAssertEqual(ApplyZoomChoice.defaultAction(previouslyKept: true), .keep)

        for axis in 0..<3 {
            XCTAssertEqual(ApplyZoomChoice.initialAxisAction(axis: axis, zoomed: true, simple: .reset, incrementalX: true, follows: true), .reset)
        }
        XCTAssertEqual(ApplyZoomChoice.initialAxisAction(axis: 0, zoomed: true, simple: .keep, incrementalX: true, follows: false), .keep)
        XCTAssertEqual(ApplyZoomChoice.initialAxisAction(axis: 1, zoomed: true, simple: .keep, incrementalX: true, follows: true), .keep)
        XCTAssertEqual(ApplyZoomChoice.initialAxisAction(axis: 2, zoomed: false, simple: .keep, incrementalX: true, follows: true), .reset, "not zoomed")
        XCTAssertEqual(ApplyZoomChoice.initialAxisAction(axis: 0, zoomed: true, simple: .keep, incrementalX: true, follows: true), .follow)
        XCTAssertEqual(ApplyZoomChoice.initialAxisAction(axis: 0, zoomed: true, simple: .keep, incrementalX: false, follows: true), .keep, "follow is only offered on an incremental x axis")
    }

    func testResettingOneAxisKeepsTheOthers() throws {
        let graph = try graph(plain)
        graph.zoomManager.applyExternalZoom(x: (min: 1, max: 3), y: (min: 0, max: 2), z: (min: 5, max: 6))

        graph.zoomManager.applyZoomSettings(modeX: .reset, applyToX: .this, modeY: .none, applyToY: .this, modeZ: .keep)
        XCTAssertNil(graph.zoomManager.zoomRange(axis: 0))
        XCTAssertEqual(graph.zoomManager.zoomRange(axis: 1)?.max, 2)
        XCTAssertEqual(graph.zoomManager.zoomRange(axis: 2)?.min, 5, "resetting x keeps the z zoom")

        graph.zoomManager.applyZoomSettings(modeX: .none, applyToX: .this, modeY: .reset, applyToY: .this, modeZ: .keep)
        XCTAssertNil(graph.zoomManager.zoomRange(axis: 1))
        XCTAssertEqual(graph.zoomManager.zoomRange(axis: 2)?.max, 6, "resetting y keeps the z zoom")

        graph.zoomManager.applyZoomSettings(modeX: .none, applyToX: .this, modeY: .none, applyToY: .this, modeZ: .reset)
        XCTAssertNil(graph.zoomManager.zoomRange(axis: 2))
        XCTAssertFalse(graph.zoomManager.anyZoomed)
    }

    //"Keep and follow new data" from the dialog makes this graph follow, and "any x axis" carries the window and the
    //follow mode to the other graphs of the page; a propagated reset resets them
    func testFollowFromTheDialogReachesThisGraphAndTheOthers() throws {
        let xml = """
        <phyphox xmlns="http://phyphox.org/xml" version="1.21" locale="en">
            <title>zoom</title><category>test</category><description>d</description>
            <data-containers>
                <container size="5" init="0,1,2,3,4">t</container>
                <container size="5" init="0,2,1,4,3">a</container>
            </data-containers>
            <views><view label="v">
                <graph label="first" labelX="t" unitX="s" labelY="a" unitY="m" partialUpdate="true"><input axis="x">t</input><input axis="y">a</input></graph>
                <graph label="second" labelX="t" unitX="s" labelY="a" unitY="m" partialUpdate="true"><input axis="x">t</input><input axis="y">a</input></graph>
            </view></views>
        </phyphox>
        """
        let experiment = try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: InputStream(data: Data(xml.utf8)))
        let modules = ExperimentViewModuleFactory.createViews(try XCTUnwrap(experiment.viewDescriptors?.first), resourceFolder: nil)
        let controller = ExperimentViewController(modules: modules) //wires zoomDelegate and layoutDelegate
        let first = try XCTUnwrap(modules[0].view as? ExperimentGraphView)
        let second = try XCTUnwrap(modules[1].view as? ExperimentGraphView)
        withExtendedLifetime(controller) {
            first.zoomManager.applyExternalZoom(x: (min: 1, max: 3), y: nil)
            XCTAssertFalse(first.zoomManager.isZoomFollows)

            first.applyZoomDialogResult(modeX: .follow, applyToX: .sameAxis, modeY: .reset, applyToY: .this, modeZ: .reset)
            XCTAssertTrue(first.zoomManager.isZoomFollows, "this graph follows")
            XCTAssertTrue(second.zoomManager.isZoomFollows, "the other graph follows as well")
            XCTAssertEqual(second.zoomManager.zoomRange(axis: 0)?.min, 1, "with the same window")
            XCTAssertEqual(second.zoomManager.zoomRange(axis: 0)?.max, 3)

            first.applyZoomDialogResult(modeX: .keep, applyToX: .sameAxis, modeY: .reset, applyToY: .this, modeZ: .reset)
            XCTAssertFalse(second.zoomManager.isZoomFollows, "keep stops following on the other graph too")
            XCTAssertEqual(second.zoomManager.zoomRange(axis: 0)?.max, 3)

            first.applyZoomDialogResult(modeX: .reset, applyToX: .sameAxis, modeY: .reset, applyToY: .this, modeZ: .reset)
            XCTAssertFalse(second.zoomManager.anyZoomed, "a propagated reset resets the other graph")
        }
    }

    func testAxisTitlesShowTheZoomInTheDisplayUnitLikeTheTicLabels() throws {
        let graph = try graph(plain)
        XCTAssertNil(graph.zoomRangeLine(axis: 0), "no range while the axis is not zoomed")

        graph.zoomManager.applyExternalZoom(x: (min: 2, max: 4.5), y: (min: 0, max: 3))
        XCTAssertEqual(graph.zoomRangeLine(axis: 0), "t: 2.0 s to 4.5 s")
        XCTAssertEqual(graph.zoomRangeLine(axis: 1), "a: 0 m/s² to 3 m/s²")

        graph.setDisplayUnit(axis: 1, id: "foot_per_square_second")
        XCTAssertEqual(graph.zoomRangeLine(axis: 1), "a: 0 ft/s² to 10 ft/s²")
    }
}
