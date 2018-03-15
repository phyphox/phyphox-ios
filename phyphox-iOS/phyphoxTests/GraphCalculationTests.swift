//
//  GraphCalculationTests.swift
//  phyphoxTests
//
//  Created by Jonas Gessner on 09.03.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import UIKit
import XCTest

final class GraphCalculationTests: XCTestCase {
    func mergingFactor(range: Double, longestStride: Double, graphWidth: CGFloat) -> Int {
        let graphCoordinatesPerPixel = range / graphWidth

        let drawnPointsPerPixel = 2 * graphCoordinatesPerPixel / longestStride

        return Int(drawnPointsPerPixel)
    }

    func testPointMerging() {
        let graphWidth = 100.0

        let pointRange = 200.0

        let longestStride = 200.0

        let factor = mergingFactor(range: pointRange, longestStride: longestStride, graphWidth: graphWidth)

        print(factor)
    }
}
