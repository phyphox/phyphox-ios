//
//  GraphEmptyStateTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

// phyphox-test: graph-empty-state
//An empty plot area says why it is empty: "No data" while nothing has been measured, "No valid data" when everything
//is NaN or one axis has no values, and "No data in range" with an arrow towards the nearest point when valid data
//lies outside the current range. The classification and the opened zero range are computed by GraphDataManager on
//its own queue and delivered to the graph view; the tests catch the delivery with a spy delegate.
final class GraphEmptyStateTests: XCTestCase {
    private static let plotSize = CGSize(width: 600, height: 400)

    private final class Spy: GraphDataManagerDelegate {
        var status: GraphDataStatus? = nil
        var result: GraphDataResult? = nil
        var expectation: XCTestExpectation? = nil

        func dataManager(_ manager: GraphDataManager, didUpdateData data: GraphDataResult, pauseMarkers: PauseRanges?) {
            status = data.dataStatus
            result = data
            expectation?.fulfill()
        }

        func dataManagerDidClearData(status: GraphDataStatus) {
            self.status = status
            result = nil
            expectation?.fulfill()
        }
    }

    private var x: DataBuffer!
    private var y: DataBuffer!
    private var descriptor: GraphViewDescriptor!
    private var manager: GraphDataManager!
    private var spy: Spy!

    //A graph over the buffers x and y with the given graph attributes, parsed like any experiment
    private func makeGraph(_ attributes: String = "") throws {
        let xml = """
        <phyphox version="1.20">
            <title>graph empty state</title>
            <category>test</category>
            <description>d</description>
            <data-containers>
                <container size="0">x</container>
                <container size="0">y</container>
            </data-containers>
            <views>
                <view label="v">
                    <graph label="g" \(attributes)>
                        <input axis="x">x</input>
                        <input axis="y">y</input>
                    </graph>
                </view>
            </views>
        </phyphox>
        """
        let stream = InputStream(data: xml.data(using: .utf8)!)
        let experiment = try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: stream)
        guard let descriptor = experiment.viewDescriptors?.first?.views.first as? GraphViewDescriptor else {
            XCTFail("the fixture holds no graph")
            return
        }
        self.descriptor = descriptor
        x = try XCTUnwrap(experiment.buffers["x"])
        y = try XCTUnwrap(experiment.buffers["y"])
        spy = Spy()
        manager = GraphDataManager(descriptor: descriptor, timeReference: experiment.timeReference)
        manager.delegate = spy
        manager.plotSize = GraphEmptyStateTests.plotSize
    }

    private func show(x xValues: [Double], y yValues: [Double]) {
        x.replaceValues(xValues)
        y.replaceValues(yValues)
    }

    //y = 2x + 1 on x = 0..8
    private func showLine() {
        show(x: [0, 1, 2, 3, 4, 5, 6, 7, 8], y: [1, 3, 5, 7, 9, 11, 13, 15, 17])
    }

    //One update of the data manager, delivered to the spy
    @discardableResult private func update(file: StaticString = #filePath, line: UInt = #line) -> GraphDataResult? {
        let expectation = expectation(description: "graph data delivered")
        spy.expectation = expectation
        manager.setNeedsUpdate()
        manager.performUpdate()
        wait(for: [expectation], timeout: 5)
        spy.expectation = nil
        return spy.result
    }

    private func zoom(minX: Double, maxX: Double, minY: Double, maxY: Double) {
        manager.updateZoomState(min: GraphPoint3D(x: minX, y: minY, z: .nan), max: GraphPoint3D(x: maxX, y: maxY, z: .nan), follows: false)
    }

    private func tickValues(_ lines: [GraphGridLine]) -> [Double] {
        return lines.map { $0.absoluteValue }
    }

    // ------------------------------------------------ classification

    func testNothingAddedYetIsNoData() throws {
        try makeGraph()
        update()
        XCTAssertEqual(spy.status, .noData)
    }

    func testAllInvalidIsNoValidData() throws {
        try makeGraph()
        show(x: [0, 1, 2], y: [.nan, .infinity, -.infinity])
        update()
        XCTAssertEqual(spy.status, .noValidData)
    }

    func testOneEmptyAxisIsNoValidData() throws {
        try makeGraph()
        show(x: [0, 1, 2], y: [])
        update()
        XCTAssertEqual(spy.status, .noValidData)

        show(x: [], y: [0, 1, 2])
        update()
        XCTAssertEqual(spy.status, .noValidData)
    }

    func testInvalidOnOneAxisOnlyWhereTheOtherIsValidIsNoValidData() throws {
        try makeGraph()
        //x is valid where y is not and vice versa: not a single drawable pair
        show(x: [0, .nan], y: [.nan, 5])
        update()
        XCTAssertEqual(spy.status, .noValidData)
    }

    func testVisibleDataIsOk() throws {
        try makeGraph()
        showLine()
        let result = try XCTUnwrap(update())
        XCTAssertEqual(result.dataStatus, .ok)
        XCTAssertNil(result.arrowAngle)
    }

    func testASingleValidPointAmongInvalidOnesIsOk() throws {
        try makeGraph()
        show(x: [0, 1, 2], y: [.nan, 3, .nan])
        update()
        XCTAssertEqual(spy.status, .ok)
    }

    func testZoomedPastTheDataPointsBackToIt() throws {
        try makeGraph()
        showLine()
        //the line ends at x = 8; look at x = 20..30 and the y range it covers
        zoom(minX: 20, maxX: 30, minY: 0, maxY: 20)
        let result = try XCTUnwrap(update())
        XCTAssertEqual(result.dataStatus, .noDataInRange)
        //the nearest point (8, 17) is left of the plot area and within its vertical extent, so the arrow points left
        let angle = try XCTUnwrap(result.arrowAngle)
        XCTAssertEqual(abs(angle), Double.pi, accuracy: 15.0 / 180.0 * Double.pi)

        manager.updateZoomState(min: nil, max: nil, follows: false)
        update()
        XCTAssertEqual(spy.status, .ok)
    }

    func testZoomedBelowTheDataPointsUp() throws {
        try makeGraph()
        showLine()
        zoom(minX: 0, maxX: 8, minY: -30, maxY: -10)
        let result = try XCTUnwrap(update())
        XCTAssertEqual(result.dataStatus, .noDataInRange)
        //(0, 1) is the closest to the plot area: above it, so the arrow points upwards (screen y grows downwards)
        let angle = try XCTUnwrap(result.arrowAngle)
        XCTAssertLessThan(angle, 0)
        XCTAssertGreaterThan(angle, -Double.pi)
    }

    func testFixedRangeAwayFromTheDataIsNoDataInRange() throws {
        try makeGraph("scaleMinX=\"fixed\" minX=\"100\" scaleMaxX=\"fixed\" maxX=\"200\" scaleMinY=\"fixed\" minY=\"0\" scaleMaxY=\"fixed\" maxY=\"20\"")
        showLine()
        let result = try XCTUnwrap(update())
        XCTAssertEqual(result.dataStatus, .noDataInRange)
        let angle = try XCTUnwrap(result.arrowAngle)
        XCTAssertEqual(abs(angle), Double.pi, accuracy: 15.0 / 180.0 * Double.pi)
    }

    func testNonPositiveValuesOnALogAxisCountAsOutOfRangeNotInvalid() throws {
        try makeGraph("logX=\"true\"")
        show(x: [-3, -2, -1], y: [1, 2, 3])
        let result = try XCTUnwrap(update())
        XCTAssertEqual(result.dataStatus, .noDataInRange)
        let angle = try XCTUnwrap(result.arrowAngle)
        XCTAssertEqual(abs(angle), Double.pi, accuracy: 15.0 / 180.0 * Double.pi)
    }

    // ------------------------------------------------ a single distinct value

    func testASinglePointAtZeroGetsARangeAndOneTicPerAxis() throws {
        try makeGraph()
        show(x: [0], y: [0])
        let result = try XCTUnwrap(update())
        XCTAssertEqual(result.dataStatus, .ok)
        XCTAssertGreaterThan(result.bounds.max.x, result.bounds.min.x)
        XCTAssertGreaterThan(result.bounds.max.y, result.bounds.min.y)
        XCTAssertEqual(tickValues(result.grid.xGridLines), [0])
        XCTAssertEqual(tickValues(result.grid.yGridLines), [0])
        XCTAssertEqual(result.grid.xGridLines[0].precision, 0)
        XCTAssertEqual(result.grid.xGridLines[0].relativeValue, 0.5, accuracy: 1e-9)
    }

    func testASingleNegativeValueDoesNotInvertTheAxis() throws {
        try makeGraph()
        show(x: [-10, -10, -10], y: [1, 2, 3])
        let result = try XCTUnwrap(update())
        XCTAssertGreaterThan(result.bounds.max.x, result.bounds.min.x)
        XCTAssertLessThan(result.bounds.min.x, -10)
        XCTAssertGreaterThan(result.bounds.max.x, -10)
        XCTAssertEqual(tickValues(result.grid.xGridLines), [-10])
        XCTAssertEqual(result.dataStatus, .ok)
    }

    func testTheSingleTicShowsTheValueExactly() throws {
        try makeGraph()
        show(x: [0, 1, 2], y: [9.81, 9.81, 9.81])
        let result = try XCTUnwrap(update())
        XCTAssertEqual(result.grid.yGridLines.count, 1)
        XCTAssertEqual(result.grid.yGridLines[0].absoluteValue, 9.81, accuracy: 1e-6)
        XCTAssertEqual(result.grid.yGridLines[0].precision, 2)
    }

    func testASingleValueOnALogAxisOpensAroundIt() throws {
        try makeGraph("logY=\"true\"")
        show(x: [0, 1, 2], y: [100, 100, 100])
        let result = try XCTUnwrap(update())
        //log axes hold the logarithm of the value
        XCTAssertLessThan(exp(result.bounds.min.y), 100)
        XCTAssertGreaterThan(exp(result.bounds.max.y), 100)
        XCTAssertGreaterThan(exp(result.bounds.min.y), 0)
        XCTAssertEqual(exp(result.bounds.min.y), 100 / 1.05, accuracy: 1e-9)
        XCTAssertEqual(tickValues(result.grid.yGridLines), [100])
        XCTAssertEqual(result.dataStatus, .ok)
    }

    func testASingleValueOnATimeAxisOpensAroundIt() throws {
        try makeGraph("timeOnX=\"true\"")
        show(x: [0], y: [5])
        let result = try XCTUnwrap(update())
        XCTAssertGreaterThan(result.bounds.max.x, result.bounds.min.x)
        XCTAssertEqual(tickValues(result.grid.xGridLines), [0])
        XCTAssertEqual(result.dataStatus, .ok)
    }

    func testTheOpenedRangeDoesNotStickToAnExtendAxis() throws {
        //an extend axis with all values at 3 shows the opened range...
        try makeGraph("scaleMinX=\"extend\" scaleMaxX=\"extend\"")
        show(x: [3, 3, 3], y: [1, 2, 3])
        var result = try XCTUnwrap(update())
        XCTAssertGreaterThan(result.bounds.max.x, result.bounds.min.x)
        XCTAssertEqual(result.grid.xGridLines.count, 1)

        //...but new data extends from 3, not from the opened range: 3..4 plus the 5 % headroom
        show(x: [3, 3.5, 4], y: [1, 2, 3])
        result = try XCTUnwrap(update())
        XCTAssertEqual(result.bounds.min.x, 3 - 0.05, accuracy: 1e-6)
        XCTAssertEqual(result.bounds.max.x, 4 + 0.05, accuracy: 1e-6)
        XCTAssertGreaterThan(result.grid.xGridLines.count, 1)
    }

    // ------------------------------------------------ headroom

    func testOnlyDataDeterminedEndsGetHeadroom() throws {
        //auto ends are padded by 5 % of the range, a fixed end is shown exactly (decided 2026-09-20)
        try makeGraph("scaleMinY=\"fixed\" minY=\"0\"")
        showLine()
        var result = try XCTUnwrap(update())
        XCTAssertEqual(result.bounds.min.y, 0, accuracy: 1e-9)
        XCTAssertEqual(result.bounds.max.y, 17 + 0.85, accuracy: 1e-9)
        XCTAssertEqual(result.bounds.min.x, -0.4, accuracy: 1e-9)
        XCTAssertEqual(result.bounds.max.x, 8.4, accuracy: 1e-9)

        //a zoomed range is what the user set
        zoom(minX: 2, maxX: 4, minY: 0, maxY: 10)
        result = try XCTUnwrap(update())
        XCTAssertEqual(result.bounds.min.x, 2, accuracy: 1e-9)
        XCTAssertEqual(result.bounds.max.x, 4, accuracy: 1e-9)
        XCTAssertEqual(result.bounds.min.y, 0, accuracy: 1e-9)
        XCTAssertEqual(result.bounds.max.y, 10, accuracy: 1e-9)
    }

    func testAFullyFixedRangeIsShownExactly() throws {
        try makeGraph("scaleMinY=\"fixed\" minY=\"0\" scaleMaxY=\"fixed\" maxY=\"10\"")
        showLine()
        let result = try XCTUnwrap(update())
        XCTAssertEqual(result.bounds.min.y, 0, accuracy: 1e-9)
        XCTAssertEqual(result.bounds.max.y, 10, accuracy: 1e-9)
    }

    // ------------------------------------------------ the note itself

    private func inkBounds(of view: GraphDataStatusView) -> CGRect? {
        let renderer = UIGraphicsImageRenderer(size: view.bounds.size, format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return format
        }())
        let image = renderer.image { context in
            view.layer.render(in: context.cgContext)
        }
        guard let cgImage = image.cgImage, let data = cgImage.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return nil }
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for py in 0..<cgImage.height {
            for px in 0..<cgImage.width {
                let alpha = bytes[py * bytesPerRow + px * bytesPerPixel + 3]
                if alpha > 0 {
                    minX = min(minX, px); maxX = max(maxX, px)
                    minY = min(minY, py); maxY = max(maxY, py)
                }
            }
        }
        guard maxX >= 0 else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    func testTheNoteIsCenteredAndTheArrowIsDrawnNextToIt() throws {
        let view = GraphDataStatusView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let textSize = SettingBundleHelper.getGraphSettingLabelSize() * 0.85

        view.show(.ok, arrowAngle: nil)
        XCTAssertTrue(view.isHidden)

        view.show(.noDataInRange, arrowAngle: nil)
        XCTAssertFalse(view.isHidden)
        XCTAssertEqual(view.accessibilityLabel, "No data in range")
        let textOnly = try XCTUnwrap(inkBounds(of: view))
        XCTAssertEqual(textOnly.midX, 150, accuracy: 2)
        XCTAssertEqual(textOnly.midY, 100, accuracy: textSize)

        //the arrow (pointing right) adds its length and the gap to the right of the text, both stay centered together
        view.show(.noDataInRange, arrowAngle: 0)
        let withArrow = try XCTUnwrap(inkBounds(of: view))
        XCTAssertEqual(withArrow.midX, 150, accuracy: 2)
        XCTAssertEqual(withArrow.width - textOnly.width, textSize * 1.7, accuracy: textSize * 0.3)
        XCTAssertEqual(withArrow.minX, textOnly.minX - textSize * 0.85, accuracy: textSize * 0.2)
        XCTAssertLessThan(withArrow.height, textSize * 2)

        view.show(.noData, arrowAngle: 0)
        XCTAssertNil(view.arrowAngle, "only the in-range note carries an arrow")
        XCTAssertEqual(view.accessibilityLabel, "No data")
    }
}
