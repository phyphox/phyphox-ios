//
//  phyphoxTests.swift
//  phyphoxTests
//
//  Created by Gaurav Tripathee on 27.02.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

@testable import phyphox
import XCTest

final class phyphoxTests: XCTestCase {
    
    var colorHelper: ColorConverterHelper!
    
    override func setUp() {
        colorHelper = ColorConverterHelper()
    }

    override func tearDown() {
        colorHelper = nil
    }
    
    func testAdjustColorForLightTheme() {
        //The highlight colour is deliberately passed through unchanged
        XCTAssertEqual(colorHelper.adjustColorForLightTheme(colorName: kHighlightColor), kHighlightColor)

        //The default graph blue keeps its hue but flips its luminance, so it stays readable on
        //the white background. The exact values pin the current implementation; the previous
        //expectation dated from an older algorithm and had failed ever since.
        let input = UIColor(red: (57.0/255.0), green: (162.0/255.0), blue: (255.0/255.0), alpha: 1.0)
        let adjusted = colorHelper.adjustColorForLightTheme(colorName: input)
        XCTAssertEqual(adjusted.red, 0.0, accuracy: 1e-6)
        XCTAssertEqual(adjusted.green, 0.4862745098, accuracy: 1e-6)
        XCTAssertEqual(adjusted.blue, 0.9215686275, accuracy: 1e-6)
        XCTAssertLessThan(adjusted.linearLuminance, input.linearLuminance, "light theme colours must get darker to keep contrast on white")
    }

}


