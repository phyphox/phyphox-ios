//
//  DataBuffer.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

protocol DataBufferObserver : AnyObject {
    func dataBufferUpdated(_ buffer: DataBuffer, noData: Bool) //noData signifies that the buffer has changed, but contains no data (in practice: Update views, but do not attempt calculations on this data)
    func analysisComplete()
}

/**
 Data buffer used for raw or processed data from sensors.
 */
final class DataBuffer {
    let name: String
    var size: Int {
        didSet {
            sync {
                if size > 0 && queue.count > size {
                    removeFirst(queue.count - size)
                }
            }
        }
    }

    var attachedToTextField = false
    var dataFromAnalysis = false
    
    var hashValue: Int {
        return name.hash
    }

    private var stateToken: UUID?
    
    private var observers = NSMutableOrderedSet()
    
    /**
     Notifications are sent in order, first registered, first notified.
     */
    func addObserver(_ observer: DataBufferObserver) {
        observers.add(observer)
    }
    
    func removeObserver(_ observer: DataBufferObserver) {
        observers.remove(observer)
    }
    
    /**
     A state token represents a state of the data contained in the buffer. Whenever the data in the buffer changes the current state token gets invalidated.
     */
    func getStateToken() -> UUID? {
        if stateToken == nil {
            stateToken = UUID()
        }
        
        return stateToken
    }
    
    func stateTokenIsValid(_ token: UUID?) -> Bool {
        return token != nil && stateToken != nil && stateToken == token
    }
    
    private func bufferMutated() {
        stateToken = nil
    }

    var staticBuffer: Bool = false
    var written: Bool = false
    
    var count: Int {
        if size > 0 {
            return Swift.min(queue.count, size)
        } else {
            return queue.count
        }
    }

    private let queueLock = DispatchQueue(label: "de.j-gessner.queue.lock", attributes: [])
    private var queue: Queue<Double>
    
    init(name: String, size: Int) {
        self.name = name
        self.size = size
        queue = Queue<Double>(capacity: size)
    }
    
    func sendUpdateNotification(_ noData: Bool = false) {
        for observer in observers {
            mainThread {
                (observer as! DataBufferObserver).dataBufferUpdated(self, noData: noData)
            }
        }
    }
    
    func sendAnalysisCompleteNotification() {
        for observer in observers {
            mainThread {
                (observer as! DataBufferObserver).analysisComplete()
            }
        }
    }

    func sync<T>(body: () throws -> T) rethrows -> T {
        return try queueLock.sync(execute: body)
    }

    func objectAtIndex(_ index: Int) -> Double? {
        return sync {
            return queue.objectAtIndex(index)
        }
    }

    func removeFirst(_ n: Int) {
        sync {
            queue.removeFirst(n)
        }
    }
    
    func clear(_ notify: Bool = true, noData: Bool = true) {
        sync {
            queue.clear()
            written = false
        }
        
        bufferMutated()
        
        if notify {
            sendUpdateNotification(noData)
        }
    }
    
    func replaceValues(_ values: [Double], notify: Bool = true) {
        if !staticBuffer || !written {
            var cutValues = values

            sync {
                written = true

                if cutValues.count > size && size > 0 {
                    cutValues = Array(cutValues[cutValues.count-size..<cutValues.count])
                }

                queue.replaceValues(cutValues)
            }

            bufferMutated()
            
            if notify {
                sendUpdateNotification()
            }
        }
    }
    
    func append(_ value: Double?, notify: Bool = true) {
        if (!staticBuffer || !written), let value = value {
            sync {
                written = true

                self.queue.enqueue(value)

                if size > 0 && queue.count > size {
                    _ = queue.dequeue()
                }
            }

            bufferMutated()
            
            if notify {
                sendUpdateNotification()
            }
        }
    }
    
    func appendFromArray(_ values: [Double], notify: Bool = true) {
        guard !values.isEmpty else { return }
        
        if !staticBuffer || !written {
            sync {
                written = true

                autoreleasepool {
                    let sizeAfterAppend = count + values.count

                    let cutSize = sizeAfterAppend - size
                    let shouldCut = size > 0 && cutSize > 0

                    let cutAfterAppend = cutSize > count

                    if shouldCut && !cutAfterAppend {
                        queue.removeFirst(cutSize)
                    }

                    queue.enqueue(values)

                    if shouldCut && cutAfterAppend {
                        queue.removeFirst(cutSize)
                    }
                }
            }
            
            bufferMutated()
            
            if notify {
                sendUpdateNotification()
            }
        }
    }

    func toArray() -> [Double] {
        return queue.toArray()
    }
}

extension DataBuffer: Sequence {
    func makeIterator() -> IndexingIterator<[Double]> {
        return queue.makeIterator()
    }

    var last: Double? {
        return sync { queue.last }
    }

    var first: Double? {
        return sync { queue.first }
    }

    subscript(index: Int) -> Double {
        return sync { queue[index] }
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
        get {
            return "<\(type(of: self)): \(Unmanaged.passUnretained(self).toOpaque()): \(queue.toArray())>"
        }
    }
}

//extension DataBuffer: Equatable {
//    static func ==(lhs: DataBuffer, rhs: DataBuffer) -> Bool {
//        return lhs.name == rhs.name && lhs.size == rhs.size && fir lhs.toArray() == rhs.toArray()
//    }
//}

