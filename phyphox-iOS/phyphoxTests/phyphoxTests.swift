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
    
    override class func setUp() {
        colorHelper = ColorConverterHelper()
    }
    
    override class func tearDown() {
        colorHelper = nil
    }
    
    func testAjustColor(){
        
        // Given - Arrange
        var expected: UIColor
        var input: UIColor = UIColor(red:  (57.0/255.0), green: (162.0/255.0), blue: (255.0/255.0), alpha: 1.0) // For blue
        
        
        // When - Act
        expected = colorHelper.adjustColorForLightTheme(colorName: input)
        
        // Then - Assert
        XCTAssert(expected == UIColor(red:  0.705882, green: 0.776471, blue: 0.0, alpha: 1.0)) // adjust for blue
        
        
    }

}
