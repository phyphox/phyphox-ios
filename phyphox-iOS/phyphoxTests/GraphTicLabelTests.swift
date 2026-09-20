//
//  GraphTicLabelTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

//Tic labels of a range whose outer tics sit right on the plot border (fixed ranges, zoom): an interior label is
//centred on its tic, a border label is moved inside the plot's width (x) or height (y) instead of hanging into the
//neighbouring label row or beyond the view. Mirrors Android's GraphTicLabelTest.
final class GraphTicLabelTests: XCTestCase {
    private var gridView: GraphGridView!
    private var labels: [UILabel] = []

    override func setUpWithError() throws {
        gridView = GraphGridView(descriptor: nil, isZScale: false)
        gridView.frame = CGRect(x: 0, y: 0, width: 300, height: 200)
        gridView.gridInset = CGPoint(x: 2, y: 2)
        //x: 0, 4000, 8000 and y: -1, 2.5, 6 - the outer tics on the borders, the wide "8,000" at the right one
        gridView.grid = GraphGrid(
            xGridLines: [GraphGridLine(absoluteValue: 0, relativeValue: 0, precision: 0),
                         GraphGridLine(absoluteValue: 4000, relativeValue: 0.5, precision: 0),
                         GraphGridLine(absoluteValue: 8000, relativeValue: 1, precision: 0)],
            yGridLines: [GraphGridLine(absoluteValue: -1, relativeValue: 0, precision: 0),
                         GraphGridLine(absoluteValue: 2.5, relativeValue: 0.5, precision: 1),
                         GraphGridLine(absoluteValue: 6, relativeValue: 1, precision: 0)],
            zGridLines: [], systemTimeOffsetX: 0, systemTimeOffsetY: 0)
        gridView.layoutIfNeeded()
        //created in grid order: the three x labels, then the three y labels
        labels = gridView.subviews.compactMap { $0 as? UILabel }
        XCTAssertEqual(labels.count, 6)
        XCTAssertEqual(labels[2].text, "8,000")
    }

    private var plot: CGRect { gridView.insetRect }

    func testInteriorLabelsAreCentredOnTheirTic() {
        XCTAssertEqual(labels[1].frame.midX, plot.midX, accuracy: 1)
        XCTAssertEqual(labels[4].frame.midY, plot.midY, accuracy: 1)
    }

    func testBorderXLabelsStayWithinThePlotWidth() {
        XCTAssertGreaterThanOrEqual(labels[0].frame.minX, plot.minX - 0.5, "the \"0\" starts at the left border, not centred on it")
        XCTAssertLessThan(labels[0].frame.midX, plot.minX + labels[0].frame.width, "shifted by at most half its width")
        XCTAssertLessThanOrEqual(labels[2].frame.maxX, gridView.bounds.maxX + 0.5, "the \"8,000\" ends inside the view")
        XCTAssertGreaterThan(labels[2].frame.width, 30, "the whole label is there")
    }

    func testBorderYLabelsKeepTheirDigitsWithinThePlotHeight() {
        let halfGlyph = labels[5].font.capHeight / 2
        XCTAssertGreaterThanOrEqual(labels[5].frame.midY - halfGlyph, plot.minY - 0.5, "the \"6\" does not rise above the plot top")
        XCTAssertLessThanOrEqual(labels[3].frame.midY + halfGlyph, plot.maxY + 0.5, "the \"-1\" does not hang below the plot bottom, into the x labels")
        //and each is shifted by at most half its line height from its tic
        XCTAssertLessThan(abs(labels[5].frame.midY - plot.minY), labels[5].frame.height / 2 + 0.5)
        XCTAssertLessThan(abs(labels[3].frame.midY - plot.maxY), labels[3].frame.height / 2 + 0.5)
    }
}
