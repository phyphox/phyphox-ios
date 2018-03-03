//
//  BufferTests.swift
//  phyphoxTests
//
//  Created by Jonas Gessner on 02.03.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import UIKit
import XCTest
@testable import phyphox

final class BufferTests: XCTestCase {
    func testConcurrency() {
        let numberOfIterations = 200_000

        let buffer = DataBuffer(name: UUID().uuidString, storage: .memory(size: numberOfIterations), baseContents: [])

        let addingExpectation = expectation(description: "Adding Completed")

        let addingQueue = DispatchQueue(label: "adding", attributes: [])

        addingQueue.async {
            for i in 0..<numberOfIterations {
                buffer.append(Double(i))
            }

            addingExpectation.fulfill()
        }

        var deletingDone = false

        let deletingExpectation = expectation(description: "Deleting Completed")
        let deletingQueue = DispatchQueue(label: "deleting", attributes: [])

        deletingQueue.async {
            var i = 0
            while i < numberOfIterations {
                if buffer.count > 0 {
                    XCTAssertEqual(Double(i), buffer.first!)
                    buffer.removeFirst(1)
                    i += 1
                }
                else {
                    print("Pausing deletion for 1us")
                    usleep(1)
                }
            }

            deletingDone = true
            deletingExpectation.fulfill()
        }

        let readingQueue = DispatchQueue(label: "reading", attributes: [])
        let readingExpectation = expectation(description: "Reading Completed")

        readingQueue.async {
            while !deletingDone {
                let array = buffer.toArray()

                guard !array.isEmpty else { continue }

                for i in 0..<array.count - 1 {
                    if array[i] + 1 != array[i + 1] {
                        readingExpectation.isInverted = true
                        readingExpectation.fulfill()
                        return
                    }
                }
            }

            readingExpectation.fulfill()
        }

        waitForExpectations(timeout: 600, handler: nil)
    }
}
