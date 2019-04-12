//
//  BufferTests.swift
//  phyphoxTests
//
//  Created by Jonas Gessner on 02.03.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

private enum TestError: Error {
    case nilOptional
}

extension TestError: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .nilOptional:
            return "Found nil when force unwrapping optional"
        }
    }
}

extension Optional {
    func unwrap() throws -> Wrapped {
        switch self {
        case .some(let wrapped):
            return wrapped
        case .none:
            throw TestError.nilOptional
        }
    }
}

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

        let writeBuffer = try DataBuffer(name: UUID().uuidString, storage: .memory(size: size), baseContents: generateRandomBufferValues(of: size), static: false)

        writeBuffer.open()

        writeBuffer.appendFromArray(randomContents)

        let stateFile = generateRandomTemporaryFileURL()

        try writeBuffer.writeState(to: stateFile)

        let readBuffer = try DataBuffer(name: UUID().uuidString, storage: .memory(size: size), baseContents: generateRandomBufferValues(of: size), static: false)

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
        let writeBuffer = try DataBuffer(name: UUID().uuidString, storage: .hybrid(memorySize: size, persistentStorageLocation: writeBufferFile), baseContents: baseContents, static: false)

        writeBuffer.open()

        writeBuffer.appendFromArray(randomContents)

        let stateFile = generateRandomTemporaryFileURL()
        try writeBuffer.writeState(to: stateFile)

        XCTAssertEqual(try Data(contentsOf: stateFile), try Data(contentsOf: writeBufferFile))

        let readBufferFile = generateRandomTemporaryFileURL()
        let readBuffer = try DataBuffer(name: UUID().uuidString, storage: .hybrid(memorySize: size, persistentStorageLocation: readBufferFile), baseContents: baseContents, static: false)

        readBuffer.open()

        try readBuffer.readState(from: stateFile)

        XCTAssertEqual(try Data(contentsOf: stateFile), try Data(contentsOf: readBufferFile))

        XCTAssertEqual(readBuffer.toArray(), Array(randomContents.suffix(size)))
        XCTAssertEqual(readBuffer.toArray(), writeBuffer.toArray())

        try writeBuffer.readState(from: stateFile)

        XCTAssertEqual(try Data(contentsOf: stateFile), try Data(contentsOf: writeBufferFile))

        XCTAssertEqual(writeBuffer.toArray(), Array(randomContents.suffix(size)))
    }

    func testOverfilling() throws {
        let buffer = try DataBuffer(name: UUID().uuidString, storage: .memory(size: 10), baseContents: [], static: false)

        var expected: [Double] = []

        for _ in 0..<20 {
            let d = drand48()

            expected.append(d)

            if expected.count > 10 {
                expected.removeFirst(1)
            }

            buffer.append(d)

            XCTAssertEqual(buffer.toArray(), expected)
        }

        let fitting = (0..<5).map { _ in drand48() }

        expected += fitting
        expected.removeFirst(fitting.count)

        buffer.appendFromArray(fitting)
        XCTAssertEqual(buffer.toArray(), expected)

        let oversized1 = (0..<15).map { _ in drand48() }
        buffer.appendFromArray(oversized1)
        XCTAssertEqual(buffer.toArray(), Array(oversized1.suffix(10)))

        let oversized2 = (0..<15).map { _ in drand48() }
        buffer.replaceValues(oversized2)
        XCTAssertEqual(buffer.toArray(), Array(oversized2.suffix(10)))
    }

    func testBaseContents() throws {
        let base = (0..<5).map { _ in drand48() }

        let buffer = try DataBuffer(name: UUID().uuidString, storage: .memory(size: 10), baseContents: base, static: false)

        XCTAssertEqual(buffer.toArray(), base)

        buffer.appendFromArray(base)
        XCTAssertEqual(buffer.toArray(), base + base)

        let oversized = (0..<15).map { _ in drand48() }
        buffer.appendFromArray(oversized)
        XCTAssertEqual(buffer.toArray(), Array(oversized.suffix(10)))

        let fitting = (0..<5).map { _ in drand48() }
        buffer.replaceValues(fitting)
        XCTAssertEqual(buffer.toArray(), fitting)

        buffer.clear()
        XCTAssertEqual(buffer.toArray(), base)
    }

    func testStatic() throws {
        func testAddingToStaticBuffer(_ buffer: DataBuffer, expectedContent: [Double]) {
            buffer.append(drand48())
            XCTAssertEqual(buffer.toArray(), expectedContent)

            buffer.appendFromArray([drand48()])
            XCTAssertEqual(buffer.toArray(), expectedContent)

            buffer.clear()
            XCTAssertEqual(buffer.toArray(), expectedContent)
        }

        let buffer1 = try DataBuffer(name: UUID().uuidString, storage: .memory(size: 10), baseContents: [], static: true)

        buffer1.append(10.0)
        XCTAssertEqual(buffer1.toArray(), [10.0])

        testAddingToStaticBuffer(buffer1, expectedContent: [10.0])

        let buffer2 = try DataBuffer(name: UUID().uuidString, storage: .memory(size: 10), baseContents: [], static: true)

        buffer2.appendFromArray([10.0, 20.0])
        XCTAssertEqual(buffer2.toArray(), [10.0, 20.0])

        testAddingToStaticBuffer(buffer2, expectedContent: [10.0, 20.0])

        let buffer3 = try DataBuffer(name: UUID().uuidString, storage: .memory(size: 10), baseContents: [], static: true)

        buffer3.clear()
        XCTAssertEqual(buffer3.toArray(), [])

        testAddingToStaticBuffer(buffer3, expectedContent: [])
    }

    func testStaticWithBaseContents() throws {
        let base = (1..<5).map { _ in drand48() }

        func testAddingToStaticBuffer(_ buffer: DataBuffer, expectedContent: [Double]) {
            buffer.append(drand48())
            XCTAssertEqual(buffer.toArray(), expectedContent)

            buffer.appendFromArray([drand48()])
            XCTAssertEqual(buffer.toArray(), expectedContent)

            buffer.clear()
            XCTAssertEqual(buffer.toArray(), expectedContent)
        }

        let buffer = try DataBuffer(name: UUID().uuidString, storage: .memory(size: 10), baseContents: base, static: true)

        testAddingToStaticBuffer(buffer, expectedContent: base)
    }

    func testAddingClearingAndReplacing() throws {
        let buffer = try DataBuffer(name: UUID().uuidString, storage: .memory(size: 10), baseContents: [], static: false)

        let d1 = drand48()
        let d2 = drand48()

        let ds = (0..<5).map { _ in drand48() }

        buffer.append(d1)

        XCTAssertEqual(buffer.toArray(), [d1])
        XCTAssertEqual(buffer.last, d1)
        XCTAssertEqual(buffer.first, d1)

        buffer.append(d2)

        XCTAssertEqual(buffer.toArray(), [d1, d2])
        XCTAssertEqual(buffer.last, d2)
        XCTAssertEqual(buffer.first, d1)

        buffer.appendFromArray(ds)

        XCTAssertEqual(buffer.toArray(), [d1, d2] + ds)
        XCTAssertEqual(buffer.last, ds.last)
        XCTAssertEqual(buffer.first, d1)

        buffer.replaceValues(ds)

        XCTAssertEqual(buffer.toArray(), ds)

        buffer.removeFirst(2)

        XCTAssertEqual(buffer.toArray(), Array(ds.dropFirst(2)))

        buffer.clear()

        XCTAssertEqual(buffer.toArray(), [])
    }

    func testConcurrency() throws {
        let start = CFAbsoluteTimeGetCurrent()

        let numberOfIterations = 200_000

        let buffer = try DataBuffer(name: UUID().uuidString, storage: .memory(size: numberOfIterations), baseContents: [], static: false)

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
                    XCTAssertEqual(Double(i), try? buffer.first.unwrap())
                    XCTAssertEqual(buffer[0], try? buffer.first.unwrap())
                    buffer.removeFirst(1)
                    i += 1
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

        waitForExpectations(timeout: 600) { _ in
            print("Took \(CFAbsoluteTimeGetCurrent() - start)")
        }
    }
}
