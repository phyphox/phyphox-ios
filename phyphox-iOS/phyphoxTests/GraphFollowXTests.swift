//
//  GraphFollowXTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

// phyphox-test: graph-follow-x
//A graph with followX keeps the newest data in view from the first frame on (spec: "the graph follows new data
//with a fixed x axis scale"). Until 2026-09-20 iOS showed the minX..maxX window from the attributes until the
//first zoom gesture, because the zoom manager's initial state never reached the data manager.
final class GraphFollowXTests: XCTestCase {
    func testFollowXFollowsFromTheStart() throws {
        let xml = """
        <phyphox version="1.20">
            <title>follow</title>
            <category>test</category>
            <description>d</description>
            <data-containers>
                <container size="9" init="0,1,2,3,4,5,6,7,8">x</container>
                <container size="9" init="0,2,1,4,3,6,5,8,7">y</container>
            </data-containers>
            <views>
                <view label="v">
                    <graph label="follow x" followX="true" scaleMinX="fixed" scaleMaxX="fixed" minX="-5" maxX="0">
                        <input axis="x">x</input>
                        <input axis="y">y</input>
                    </graph>
                </view>
            </views>
        </phyphox>
        """
        let experiment = try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: InputStream(data: xml.data(using: .utf8)!))
        let modules = ExperimentViewModuleFactory.createViews(try XCTUnwrap(experiment.viewDescriptors?.first), resourceFolder: nil)
        let graph = try XCTUnwrap(modules.first?.view as? ExperimentGraphView)
        graph.frame = CGRect(x: 0, y: 0, width: 390, height: 300)
        graph.layoutIfNeeded()
        graph.setNeedsUpdate()
        graph.dataManager.performUpdate()

        //The update is delivered on the main queue; the window of width 5 ends at the newest x
        let deadline = Date().addingTimeInterval(5)
        var bounds = graph.dataManager.currentBounds
        while bounds.max.x != 8 && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            bounds = graph.dataManager.currentBounds
        }
        XCTAssertEqual(bounds.min.x, 3, accuracy: 1e-9)
        XCTAssertEqual(bounds.max.x, 8, accuracy: 1e-9)
    }
}
