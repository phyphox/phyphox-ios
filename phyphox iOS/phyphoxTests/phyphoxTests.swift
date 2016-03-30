//
//  phyphoxTests.swift
//  phyphoxTests
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

class phyphoxTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testRangefilter1() {
        let experiment = try! ExperimentSerialization.readExperimentFromFile(NSBundle(forClass: self.dynamicType).pathForResource("RangefilterTest", ofType: "phyphox")!)
        
        let write = ["buffer1" : [1.0, 2.0, 3.0, 4.0, 5.0], "buffer2" : [-100.0, 1000.0, -500.0, 500.0, 0.0], "buffer3" : [-0.1, -0.1, 0.1, 0.1, -0.2]]
        
        let read = ["out1" : [2.0, 3.0, 4.0], "out2" : [1000.0, -500.0, 500.0], "out3" : [-0.1, 0.1, 0.1]]
        
        var expectations = [XCTestExpectation]()
        
        for (key, buffer) in experiment.buffers.0! {
            if let array = write[key] {
                buffer.appendFromArray(array, notify: false)
                
                expectations.append(expectationWithDescription(key))
            }
        }
        
        experiment.analysis!.setNeedsUpdate()
        
        after(1.0) {
            for (key, buffer) in experiment.buffers.0! {
                if let array = read[key] {
                    XCTAssertEqual(buffer.toArray(), array)
                    expectations.removeLast().fulfill()
                }
            }
        }
        
        self.waitForExpectationsWithTimeout(2.0, handler: nil)
    }
    
    func testRangefilter2() {
        let experiment = try! ExperimentSerialization.readExperimentFromFile(NSBundle(forClass: self.dynamicType).pathForResource("RangefilterTest", ofType: "phyphox")!)
        
        let write = ["buffer1" : [1.0, 2.0, 3.0, 1.0, 5.0], "buffer2" : [-100.0, 1000.0, -500.0, 500.0, 0.0], "buffer3" : [-0.1, -0.1, 0.1, 0.1, -0.2]]
        
        let read = ["out1" : [2.0, 3.0], "out2" : [1000.0, -500.0], "out3" : [-0.1, 0.1]]
        
        var expectations = [XCTestExpectation]()
        
        for (key, buffer) in experiment.buffers.0! {
            if let array = write[key] {
                buffer.appendFromArray(array, notify: false)
                
                expectations.append(expectationWithDescription(key))
            }
        }
        
        experiment.analysis!.setNeedsUpdate()
        
        after(1.0) {
            for (key, buffer) in experiment.buffers.0! {
                if let array = read[key] {
                    XCTAssertEqual(buffer.toArray(), array)
                    expectations.removeLast().fulfill()
                }
            }
        }
        
        self.waitForExpectationsWithTimeout(2.0, handler: nil)
    }
    
    func testRangefilter3() {
        let experiment = try! ExperimentSerialization.readExperimentFromFile(NSBundle(forClass: self.dynamicType).pathForResource("RangefilterTest", ofType: "phyphox")!)
        
        let write = ["buffer1" : [1.0, 2.0, 3.0, 2.0, 5.0], "buffer2" : [-100.0, 1000.0, -500.0, 500.0, 0.0], "buffer3" : [-0.1, -0.1, 0.1, 0.2, -0.2]]
        
        let read = ["out1" : [2.0, 3.0], "out2" : [1000.0, -500.0], "out3" : [-0.1, 0.1]]
        
        var expectations = [XCTestExpectation]()
        
        for (key, buffer) in experiment.buffers.0! {
            if let array = write[key] {
                buffer.appendFromArray(array, notify: false)
                
                expectations.append(expectationWithDescription(key))
            }
        }
        
        experiment.analysis!.setNeedsUpdate()
        
        after(1.0) { 
            for (key, buffer) in experiment.buffers.0! {
                if let array = read[key] {
                    XCTAssertEqual(buffer.toArray(), array)
                    expectations.removeLast().fulfill()
                }
            }
        }
        
        self.waitForExpectationsWithTimeout(2.0, handler: nil)
    }
    
//    func testFFTSize() {
//        for i in 0..<2000 {
//            print("FFT size for \(i): \(nextFFTSize(i))")
//        }
//    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
