//
//  DataBuffer.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Dispatch

protocol DataBufferObserver: AnyObject {
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

/**
 A single reader/writer lock shared by all data buffers of one experiment, giving remote reads a
 consistent snapshot across buffers.

 Each `DataBuffer` is individually thread-safe, but a group of buffers written together for one
 event (a sensor sample's x/y/z/t, a camera frame's h/s/v/t, an analysis cycle's outputs) is not
 atomic across buffers on its own: a `/get` request reading the group one buffer at a time can
 catch some buffers already advanced by a concurrent write and others not, so their lengths differ
 by a sample or two (GitHub issue 22). Android avoids this with a single `experiment.dataLock` held
 across each write batch and across the remote read; this is the equivalent.

 A writer wraps its multi-buffer group in `write`; the remote `/get` handler snapshots all requested
 buffers in one `read`. Because the lock is always taken *around* buffer access and never from
 inside a `DataBuffer` (whose own lock stays the inner leaf), and is never held across a queue or
 main-thread hop, it cannot deadlock: the acquisition order is always this lock, then a buffer lock,
 never the reverse, and write groups never nest.
 */
final class BufferLock {
    private let queue = DispatchQueue(label: "de.rwth-aachen.phyphox.dataaccess", attributes: .concurrent)

    func read<T>(_ body: () throws -> T) rethrows -> T {
        return try queue.sync(execute: body)
    }

    func write(_ body: () -> Void) {
        queue.sync(flags: .barrier, execute: body)
    }
}

/**
 Runs a multi-buffer write as one atomic group with respect to remote reads. The lock is taken from
 whichever of the buffers is non-nil (they all share the experiment's lock); before the experiment
 wires up the lock, or in unit tests, it is nil and the writes run directly, exactly as before.
 */
func synchronizedBufferWrite(_ buffers: [DataBuffer?], _ body: () -> Void) {
    if let lock = buffers.lazy.compactMap({ $0?.dataLock }).first {
        lock.write(body)
    } else {
        body()
    }
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

    //The experiment-wide lock shared by all of an experiment's buffers, wired up in Experiment.init.
    //nil for a standalone buffer (e.g. in unit tests), where no cross-buffer coordination is needed.
    weak var dataLock: BufferLock?

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

    //If set, the buffer is exempt from a clear by the user unless the group is explicitly
    //selected. The reserved name "_" protects the buffer without offering it for selection.
    let clearGroup: String?

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

    init(name: String, size: Int, baseContents: [Double], static staticBuffer: Bool, clearGroup: String? = nil) throws {
        self.size = size
        self.name = name
        self.baseContents = baseContents

        contents = []
        contents.reserveCapacity(size)
        self.staticBuffer = staticBuffer
        self.clearGroup = clearGroup

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

    func clear(reset: Bool) {
        syncWrite {
            guard !staticBuffer || !written else { return }

            willWrite()

            if reset {
                contents = baseContents
            } else {
                contents = []
            }

            didWrite()
        }
    }
    
    func readAndClear(reset: Bool) -> [Double] {
        return syncWrite {
            guard !staticBuffer || !written else { return contents }

            willWrite()

            let copy = contents
            
            if reset {
                contents = baseContents
            } else {
                contents = []
            }

            didWrite()
            
            return copy
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
