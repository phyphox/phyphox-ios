//
//  DataBuffer.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Dispatch

protocol DataBufferObserver: class {
    func dataBufferUpdated(_ buffer: DataBuffer)
    func userInputTriggered(_ buffer: DataBuffer)
}

private typealias ObserverCapture = () -> DataBufferObserver?

private func weakObserverCapture(_ object: DataBufferObserver) -> ObserverCapture {
    return { [weak object] in
        return (object)
    }
}

private let isLittleEndian = CFByteOrderGetCurrent() == Int(CFByteOrderLittleEndian.rawValue)

enum DataBufferError: Error {
    case baseContentsTooLarge
}

extension DataBufferError: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .baseContentsTooLarge:
            return "Data Buffer base contents exceed memory capacity"
        }
    }
}

/**
 Data buffer used to store data from sensors or processed data from analysis modules. Thread safe.
 */
final class DataBuffer {

    let name: String
    let size: Int

    /**
     Helper value that returns `size` when `size > 0` and `Int.max` when `size == 0`.
     */
    private var effectiveMemorySize: Int {
        if size == 0 {
            return .max
        }
        else {
            return size
        }
    }

    var attachedToTextField = false

    private let baseContents: [Double]
    
    private var lazyStateToken: UUID?

    /**
     A state token represents a state of the data contained in the buffer. Whenever the data in the buffer changes the state token changes too.
     */
    var stateToken: UUID {
        if let lazyStateToken = lazyStateToken {
            return lazyStateToken
        }
        else {
            let token = UUID()
            lazyStateToken = token
            return token
        }
    }

    private var observerCaptures: [ObserverCapture] = []

    /**
     Notifications are sent in order, first registered, first notified.
     */
    func addObserver(_ observer: DataBufferObserver) {
        let alreadyRegistered = observerCaptures.contains(where: { capture in
            return capture() === observer
        })

        if !alreadyRegistered {
            let capture = weakObserverCapture(observer)
            observerCaptures.append(capture)
        }
    }

    func stateTokenIsValid(_ token: UUID) -> Bool {
        return stateToken == token
    }

    private func bufferMutated() {
        lazyStateToken = nil

        DispatchQueue.main.async {
            for observerCapture in self.observerCaptures {
                let observer = observerCapture()
                observer?.dataBufferUpdated(self)
            }
        }
    }

    func triggerUserInput() {
        DispatchQueue.main.async {
            for observerCapture in self.observerCaptures {
                let observer = observerCapture()
                observer?.userInputTriggered(self)
            }
        }
    }
    
    let staticBuffer: Bool
    private var written: Bool = false

    /**
     Total number of values stored in memory. Only the values are accessible via Collection or Sequence methods.
     */
    var memoryCount: Int {
        return syncRead{contents.count}
    }
    
    //Only to be used from within a locking queue to avoid crash
    private var directMemoryCount: Int {
        return contents.count
    }

    /**
     Total number of values stored in buffer. The number of values in memory is always at most equal to this value. Values not stored in memory are not accessible via Collection or Sequence methods.
     */
    var count: Int {
        return memoryCount
    }

    private let lockingQueue = DispatchQueue(label: "de.j-gessner.queue.lock", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)

    private var contents: [Double]

    init(name: String, size: Int, baseContents: [Double], static staticBuffer: Bool) throws {
        self.size = size
        self.name = name
        self.baseContents = baseContents

        contents = []
        contents.reserveCapacity(size)
        self.staticBuffer = staticBuffer

        guard baseContents.count <= effectiveMemorySize else {
            throw DataBufferError.baseContentsTooLarge
        }

        appendFromArray(baseContents)
    }

    private func syncWrite<T>(_ body: () throws -> T) rethrows -> T {
        return try lockingQueue.sync(flags: .barrier, execute: body)
    }

    private func syncRead<T>(_ body: () throws -> T) rethrows -> T {
        return try lockingQueue.sync(execute: body)
    }

    func objectAtIndex(_ index: Int) -> Double? {
        return syncRead {
            guard index < contents.count else {
                return nil
            }

            return contents[index]
        }
    }

    private func willWrite() {
        written = true
    }

    private func didWrite() {
        bufferMutated()
    }

    func removeFirst(_ n: Int) {
        syncWrite {
            contents.removeFirst(n)
        }
    }

    func clear() {
        syncWrite {
            guard !staticBuffer || !written else { return }

            willWrite()

            contents = baseContents

            didWrite()
        }
    }

    func replaceValues(_ values: [Double]) {
        syncWrite {
            guard !staticBuffer || !written else { return }

            willWrite()

            autoreleasepool {
                var cutValues = values

                let effectiveSize = effectiveMemorySize

                if cutValues.count > effectiveSize {
                    cutValues = Array(cutValues[cutValues.count-effectiveSize..<cutValues.count])
                }

                contents = cutValues
            }

            didWrite()
        }
    }

    func append(_ value: Double) {
        syncWrite {
            guard !staticBuffer || !written else { return }

            willWrite()

            contents.append(value)

            if directMemoryCount > effectiveMemorySize {
                contents.removeFirst()
            }

            didWrite()
        }
    }

    func appendFromArray(_ values: [Double]) {
        guard !values.isEmpty else { return }

        syncWrite {
            guard !staticBuffer || !written else { return }

            willWrite()

            autoreleasepool {

                let sizeAfterAppend = directMemoryCount + values.count

                let cutSize = sizeAfterAppend - effectiveMemorySize
                let shouldCut = cutSize > 0 && sizeAfterAppend > 0

                let cutAfterAppend = cutSize > directMemoryCount

                if shouldCut && !cutAfterAppend {
                    contents.removeFirst(cutSize)
                }

                contents.append(contentsOf: values)

                if shouldCut && cutAfterAppend {
                    contents.removeFirst(cutSize)
                }
            }

            didWrite()
        }
    }

    func toArray() -> [Double] {
        return syncRead { return contents }
    }
}

extension DataBuffer: Sequence {
    func makeIterator() -> IndexingIterator<[Double]> {
        let buffered: [Double] = syncRead{contents}
        return buffered.makeIterator()
    }

    var last: Double? {
        return syncRead { contents.last }
    }

    var first: Double? {
        return syncRead { contents.first }
    }

    subscript(index: Int) -> Double {
        return syncRead { contents[index] }
    }
}

extension DataBuffer: Collection {
    func index(after i: Int) -> Int {
        return i + 1
    }

    var startIndex: Int {
        return 0
    }

    var endIndex: Int {
        return memoryCount
    }
}

extension DataBuffer: CustomStringConvertible {
    var description: String {
        return "<\(type(of: self)) \(name): \(Unmanaged.passUnretained(self).toOpaque()): \(toArray())>"
    }
}

extension DataBuffer {
    func writeState(to url: URL) throws {
        try syncWrite {
            let atomicFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

            FileManager.default.createFile(atPath: atomicFile.path, contents: nil, attributes: nil)

            let handle = try FileHandle(forWritingTo: atomicFile)
            handle.seekToEndOfFile()

            let byteSize = MemoryLayout<Double>.size

            func writeDataFromPointer(_ pointer: UnsafeMutableRawPointer) {
                let data = Data(bytesNoCopy: pointer, count: directMemoryCount * byteSize, deallocator: .none)

                handle.write(data)
                handle.closeFile()
            }

            if isLittleEndian {
                // We must guarantee that values is not deallocated before we've finished writing its memory to the file.
                withExtendedLifetime(contents, { values in
                    values.withUnsafeBytes{ pointer in
                        let rawDataPointer = UnsafeMutableRawPointer(mutating: pointer.baseAddress!)
                        writeDataFromPointer(rawDataPointer)
                    }
                })
            }
            else {
                let values = contents.map { $0.bitPattern.littleEndian }

                withExtendedLifetime(values, { values in
                    values.withUnsafeBytes{ pointer in
                        let rawDataPointer = UnsafeMutableRawPointer(mutating: pointer.baseAddress!)
                        writeDataFromPointer(rawDataPointer)
                    }
                })
            }

            try FileManager.default.moveItem(at: atomicFile, to: url)
        }
    }

}

extension DataBuffer: Equatable {
    static func ==(lhs: DataBuffer, rhs: DataBuffer) -> Bool {
        return lhs.toArray() == rhs.toArray()
    }
}
