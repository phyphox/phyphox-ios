//
//  DataBuffer.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation
import Dispatch

protocol DataBufferObserver: class {
    func dataBufferUpdated(_ buffer: DataBuffer)
}

private typealias ObserverCapture = () -> (observer: DataBufferObserver?, alwaysNotify: Bool)

private func weakObserverCapture(_ object: DataBufferObserver, alwaysNotify: Bool) -> ObserverCapture {
    return { [weak object] in
        return (object, alwaysNotify)
    }
}

private let isLittleEndian = CFByteOrderGetCurrent() == Int(CFByteOrderLittleEndian.rawValue)

/**
 Data buffer used for raw or processed data from sensors.
 */
final class DataBuffer {
    enum StorageType {
        case memory(size: Int)
        case hybrid(memorySize: Int, persistentStorageLocation: URL)
    }

    let name: String
    let size: Int

    private var effectiveMemorySize: Int {
        switch storageType {
        case .memory(size: let size):
            if size == 0 {
                return .max
            }
            else {
                return size
            }
        case .hybrid(memorySize: let memorySize, persistentStorageLocation: _):
            return memorySize
        }
    }

    var attachedToTextField = false

    private let baseContents: [Double]

    private let storageType: StorageType

    /**
     A state token represents a state of the data contained in the buffer. Whenever the data in the buffer changes the state token changes too.
     */
    private(set) var stateToken = UUID()

    private var observerCaptures: [ObserverCapture] = []

    /**
     Notifications are sent in order, first registered, first notified.
     */
    func addObserver(_ observer: DataBufferObserver, alwaysNotify: Bool) {
        let alreadyRegistered = observerCaptures.contains(where: { capture in
            return capture().observer === observer
        })

        if !alreadyRegistered {
            let capture = weakObserverCapture(observer, alwaysNotify: alwaysNotify)
            observerCaptures.append(capture)
        }
    }

    func stateTokenIsValid(_ token: UUID) -> Bool {
        return stateToken == token
    }

    private func bufferMutated() {
        stateToken = UUID()

        for observerCapture in observerCaptures {
            let (observer, alwaysNotify) = observerCapture()

            if isOpen || alwaysNotify {
                mainThread {
                    observer?.dataBufferUpdated(self)
                }
            }
        }
    }

    let staticBuffer: Bool
    private var written: Bool = false

    var count: Int {
        return Swift.min(queue.count, effectiveMemorySize)
    }

    private let queueLock = DispatchQueue(label: "de.j-gessner.queue.lock", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)

    private var queue: Queue<Double>

    init(name: String, storage: StorageType, baseContents: [Double], static staticBuffer: Bool) {
        self.name = name
        self.storageType = storage
        self.baseContents = baseContents

        switch storage {
        case .memory(size: let size):
            self.size = size
        case .hybrid(memorySize: _, persistentStorageLocation: _):
            self.size = 0
        }

        queue = Queue<Double>(capacity: size)
        self.staticBuffer = staticBuffer

        appendFromArray(baseContents)
    }

    private var persistentStorageFileHandle: FileHandle?

    private var isOpen = false

    /**
     Opening a buffer starts notifying all observers. In case of a hybrid buffer the file handle for writing data to the persistent storage is opened and the current contents of the buffer are written to the persistent storage.
     */
    func open() {
        syncWrite {
            guard !isOpen else { return }

            isOpen = true

            switch storageType {
            case .hybrid(memorySize: _, persistentStorageLocation: let url):
                if !FileManager.default.fileExists(atPath: url.path) {
                    FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
                }

                let handle = try? FileHandle(forWritingTo: url)
                handle?.truncateFile(atOffset: 0)

                persistentStorageFileHandle = handle
            case .memory(size: _):
                break
            }

            autoreleasepool {
                // Write current contents
                if let handle = persistentStorageFileHandle {
                    enumerateDataEncodedElements { data in
                        handle.write(data)
                    }
                }
            }
        }
    }

    /**
     Closing a buffer stops notifying all observers (observers that explicitly want constant updates excluded), closes the persistent storage file handle in case of a hybrid buffer and deletes the persistent storage file.
     */
    func close() {
        syncWrite {
            guard isOpen else { return }

            isOpen = false

            switch storageType {
            case .hybrid(memorySize: _, persistentStorageLocation: let url):
                persistentStorageFileHandle?.synchronizeFile()
                persistentStorageFileHandle?.closeFile()
                persistentStorageFileHandle = nil

                try? FileManager.default.removeItem(at: url)
            case .memory(size: _):
                break
            }
        }
    }

    private var hybrid: Bool {
        switch storageType {
        case .memory(size: _):
            return false
        case .hybrid(memorySize: _, persistentStorageLocation: _):
            return true
        }
    }

    private func syncWrite<T>(_ body: () throws -> T) rethrows -> T {
        return try queueLock.sync(flags: .barrier, execute: body)
    }

    private func syncRead<T>(_ body: () throws -> T) rethrows -> T {
        return try queueLock.sync(execute: body)
    }

    func objectAtIndex(_ index: Int) -> Double? {
        return syncRead {
            return queue.objectAtIndex(index)
        }
    }

    private func willWrite() {
        written = true
    }

    private func didWrite() {
        bufferMutated()
    }

    func removeFirst(_ n: Int) {
        if hybrid {
            print("Truncating a hybrid buffer is not supported.")
        }

        syncWrite {
            queue.removeFirst(n)
        }
    }

    func clear() {
        syncWrite {
            guard !staticBuffer else { return }

            willWrite()

            if isOpen, let handle = persistentStorageFileHandle {
                handle.truncateFile(atOffset: 0)
            }

            queue.replaceValues(baseContents)

            didWrite()
        }
    }

    func replaceValues(_ values: [Double]) {
        syncWrite {
            guard !staticBuffer || !written else { return }

            willWrite()

            autoreleasepool {
                var cutValues = values

                if isOpen, let handle = persistentStorageFileHandle {
                    handle.truncateFile(atOffset: 0)
                    values.enumerateDataEncodedElements { data in
                        handle.write(data)
                    }
                }

                let effectiveSize = effectiveMemorySize

                if cutValues.count > effectiveSize {
                    cutValues = Array(cutValues[cutValues.count-effectiveSize..<cutValues.count])
                }

                queue.replaceValues(cutValues)
            }

            didWrite()
        }
    }

    func append(_ value: Double) {
        syncWrite {
            guard !staticBuffer || !written else { return }

            willWrite()

            if isOpen, let handle = persistentStorageFileHandle {
                handle.write(value.encode())
            }

            self.queue.enqueue(value)

            if queue.count > effectiveMemorySize {
                _ = queue.dequeue()
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
                if isOpen, let handle = persistentStorageFileHandle {
                    values.enumerateDataEncodedElements { data in
                        handle.write(data)
                    }
                }

                let sizeAfterAppend = count + values.count

                let cutSize = sizeAfterAppend - effectiveMemorySize
                let shouldCut = cutSize > 0 && sizeAfterAppend > 0

                let cutAfterAppend = cutSize > count

                if shouldCut && !cutAfterAppend {
                    queue.removeFirst(cutSize)
                }

                queue.enqueue(values)

                if shouldCut && cutAfterAppend {
                    queue.removeFirst(cutSize)
                }
            }

            didWrite()
        }
    }

    func toArray() -> [Double] {
        return syncRead { return queue.toArray() }
    }
}

extension DataBuffer: Sequence {
    func makeIterator() -> IndexingIterator<[Double]> {
        return queue.makeIterator()
    }

    var last: Double? {
        return syncRead { queue.last }
    }

    var first: Double? {
        return syncRead { queue.first }
    }

    subscript(index: Int) -> Double {
        return syncRead { queue[index] }
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
        return count
    }
}

extension DataBuffer: CustomStringConvertible {
    var description: String {
        return "<\(type(of: self)): \(Unmanaged.passUnretained(self).toOpaque()): \(toArray())>"
    }
}

extension DataBuffer {
    func writeState(to url: URL) throws {
        try syncWrite {
            let atomicFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

            switch storageType {
            case .hybrid(memorySize: _, persistentStorageLocation: let persistentFileLocation):
                if FileManager.default.fileExists(atPath: persistentFileLocation.path) {
                    try FileManager.default.copyItem(at: persistentFileLocation, to: url)
                }
                else {
                    FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
                }

                return
            case .memory(size: _):
                FileManager.default.createFile(atPath: atomicFile.path, contents: nil, attributes: nil)
            }

            let handle = try FileHandle(forWritingTo: atomicFile)
            handle.seekToEndOfFile()

            let byteSize = MemoryLayout<Double>.size

            func writeDataFromPointer(_ pointer: UnsafeMutableRawPointer) {
                let data = Data(bytesNoCopy: pointer, count: count * byteSize, deallocator: .none)

                handle.write(data)
                handle.closeFile()
            }

            if isLittleEndian {
                let values = queue.toArray()

                // We must guarantee that values is not deallocated before we've finished writing its memory to the file.
                withExtendedLifetime(values, { values in
                    let pointer = UnsafePointer(values)
                    let rawDataPointer = UnsafeMutableRawPointer(mutating: pointer)

                    writeDataFromPointer(rawDataPointer)
                })
            }
            else {
                let values = queue.toArray().map { $0.bitPattern.littleEndian }

                withExtendedLifetime(values, { values in
                    let pointer = UnsafePointer(values)
                    let rawDataPointer = UnsafeMutableRawPointer(mutating: pointer)

                    writeDataFromPointer(rawDataPointer)
                })
            }

            try FileManager.default.moveItem(at: atomicFile, to: url)
        }
    }

    func readState(from url: URL) throws {
        let handle = try FileHandle(forReadingFrom: url)

        let singleValueSize = MemoryLayout<Double>.size

        let fileSize = Int(handle.seekToEndOfFile())
        let readingSize = Swift.min(fileSize, effectiveMemorySize * singleValueSize)
        let readingStart = UInt64(fileSize - readingSize)

        handle.seek(toFileOffset: readingStart)

        let data = handle.readData(ofLength: readingSize)
        handle.closeFile()

        let count = data.count / singleValueSize

        let values: [Double]

        if isLittleEndian {
            values = data.withUnsafeBytes { (pointer: UnsafePointer<Double>) -> [Double] in
                let buffer = UnsafeBufferPointer(start: pointer, count: count)

                return Array(buffer)
            }
        }
        else {
            values = data.withUnsafeBytes { (pointer: UnsafePointer<UInt64>) -> [Double] in
                let buffer = UnsafeBufferPointer(start: pointer, count: count)

                return buffer.map { Double(bitPattern: UInt64(littleEndian: $0)) }
            }
        }

        try syncWrite {
            switch storageType {
            case .hybrid(memorySize: _, persistentStorageLocation: let persistentFileLocation):
                // Close current file handle, copy buffer file to persistent storage location and reopen file handle at EOF
                persistentStorageFileHandle?.closeFile()
                persistentStorageFileHandle = nil

                if FileManager.default.fileExists(atPath: persistentFileLocation.path) {
                    try FileManager.default.removeItem(at: persistentFileLocation)
                }
                try FileManager.default.copyItem(at: url, to: persistentFileLocation)

                let handle = try? FileHandle(forWritingTo: url)
                handle?.seekToEndOfFile()

                persistentStorageFileHandle = handle
            case .memory(size: _):
                break
            }

            willWrite()

            queue.replaceValues(values)

            didWrite()
        }
    }
}
