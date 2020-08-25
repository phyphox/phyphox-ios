//
//  phyphox_screenshots.swift
//  phyphox screenshots
//
//  Created by Sebastian Staacks on 10.06.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import XCTest

class phyphox_screenshots: XCTestCase {

    override func setUp() {

        continueAfterFailure = false
        
        let app = XCUIApplication()
        
        setupSnapshot(app)
        
        app.launchArguments.append("screenshot")
        app.launch()

    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        
        let app = XCUIApplication()

        let label = app.alerts.element(boundBy: 0).buttons.element(boundBy: 0).label
        let index = (label == "取消" ? 0 : 1) //Detect Chinese cancel button in different order, ugly workaround...
        app.alerts.element(boundBy: 0).buttons.element(boundBy: index).tap()
        
        snapshot("screen1")
        
        let segmentedControlsQuery = app/*@START_MENU_TOKEN@*/.segmentedControls/*[[".scrollViews.segmentedControls",".segmentedControls"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        segmentedControlsQuery.buttons.element(boundBy: 2).tap()
        
        snapshot("screen2")
        
        segmentedControlsQuery.buttons.element(boundBy: 0).tap()
        
        
        let tablesQuery = XCUIApplication().tables
        tablesQuery.cells.element(boundBy: 0).staticTexts.element(boundBy: 8).tap()
        
        snapshot("screen3")
        
        app.navigationBars.element(boundBy: 0).buttons["‹"].tap()
        
        snapshot("main")
        
    }

}
