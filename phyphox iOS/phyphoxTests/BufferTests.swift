//
//  BufferTests.swift
//  phyphoxTests
//
//  Created by Jonas Gessner on 02.03.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

final class BufferTests: XCTestCase {
    func generateRandomBufferValues(of length: Int) -> [Double] {
        return repeatElement(Double(arc4random()) + 1, count: length).map { drand48() * $0 }
    }

    func generateRandomTemporaryFileURL() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

    }

    func testWritingAndReadingStateMemoryBuffer() throws {
        let size = 1000

        let randomContents = generateRandomBufferValues(of: size)

        let writeBuffer = DataBuffer(name: UUID().uuidString, storage: .memory(size: size), baseContents: generateRandomBufferValues(of: size), static: false)

        writeBuffer.open()

        writeBuffer.appendFromArray(randomContents)

        let stateFile = generateRandomTemporaryFileURL()

        try writeBuffer.writeState(to: stateFile)

        let readBuffer = DataBuffer(name: UUID().uuidString, storage: .memory(size: size), baseContents: generateRandomBufferValues(of: size), static: false)

        readBuffer.open()

        try readBuffer.readState(from: stateFile)

        XCTAssertEqual(readBuffer.toArray(), randomContents)
        XCTAssertEqual(readBuffer.toArray(), writeBuffer.toArray())

        try writeBuffer.readState(from: stateFile)

        XCTAssertEqual(writeBuffer.toArray(), randomContents)
    }

    func testWritingAndReadingStateHybridBuffer() throws {
        let size = 100000

        let randomContents = generateRandomBufferValues(of: size * 100)

        let baseContents = generateRandomBufferValues(of: Int(arc4random_uniform(UInt32(size))))

        let writeBufferFile = generateRandomTemporaryFileURL()
        let writeBuffer = DataBuffer(name: UUID().uuidString, storage: .hybrid(memorySize: size, persistentStorageLocation: writeBufferFile), baseContents: baseContents, static: false)

        writeBuffer.open()

        writeBuffer.appendFromArray(randomContents)

        let stateFile = generateRandomTemporaryFileURL()
        try writeBuffer.writeState(to: stateFile)

        XCTAssertEqual(try Data(contentsOf: stateFile), try Data(contentsOf: writeBufferFile))

        let readBufferFile = generateRandomTemporaryFileURL()
        let readBuffer = DataBuffer(name: UUID().uuidString, storage: .hybrid(memorySize: size, persistentStorageLocation: readBufferFile), baseContents: baseContents, static: false)

        readBuffer.open()

        try readBuffer.readState(from: stateFile)

        XCTAssertEqual(try Data(contentsOf: stateFile), try Data(contentsOf: readBufferFile))

        XCTAssertEqual(readBuffer.toArray(), Array(randomContents.suffix(size)))
        XCTAssertEqual(readBuffer.toArray(), writeBuffer.toArray())

        try writeBuffer.readState(from: stateFile)

        XCTAssertEqual(try Data(contentsOf: stateFile), try Data(contentsOf: writeBufferFile))

        XCTAssertEqual(writeBuffer.toArray(), Array(randomContents.suffix(size)))
    }

    func testConcurrency() {
        let numberOfIterations = 200_000

        let buffer = DataBuffer(name: UUID().uuidString, storage: .memory(size: numberOfIterations), baseContents: [], static: false)

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
                if buffer.memoryCount > 0 {
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
