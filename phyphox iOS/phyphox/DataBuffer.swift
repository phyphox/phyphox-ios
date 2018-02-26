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
final class DataBuffer: Sequence, CustomStringConvertible, Hashable {
    let name: String
    var size: Int {
        didSet {
            while count > size && size > 0 {
                _ = queue.dequeue()
            }
        }
    }
    
    var vInit: [Double]
    
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
    
    var trashedCount: Int = 0
    
    var staticBuffer: Bool = false
    var written: Bool = false
    
    var count: Int {
        get {
            if size > 0 {
                return Swift.min(queue.count, size)
            } else {
                return queue.count
            }
        }
    }
    
    var actualCount: Int {
        get {
            return queue.count
        }
    }
    
    private let queue: Queue<Double>
    
    init(name: String, size: Int, vInit: [Double]) {
        self.name = name
        self.size = size
        self.vInit = vInit
        queue = Queue<Double>(capacity: size)
        
        self.appendFromArray(vInit, notify: false)
    }
    
    func makeIterator() -> IndexingIterator<[Double]> {
        return queue.makeIterator()
    }
    
    var last: Double? {
        get {
            return queue.last
        }
    }
    
    var first: Double? {
        get {
            return queue.first
        }
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
    
    subscript(index: Int) -> Double {
        get {
            return queue[index]
        }
    }
    
    func objectAtIndex(_ index: Int, async: Bool = false) -> Double? {
        return queue.objectAtIndex(index, async: async)
    }
    
    func clear(_ notify: Bool = true, noData: Bool = true) {
        queue.clear()
        trashedCount = 0
        written = false
        
        self.appendFromArray(vInit, notify: false)
        
        bufferMutated()
        
        if notify {
            sendUpdateNotification(noData)
        }
    }
    
    func replaceValues(_ values: [Double], notify: Bool = true) {
        if !staticBuffer || !written {
            written = true
            trashedCount = 0
            
            var vals = values
            
            if vals.count > size && size > 0 {
                vals = Array(vals[vals.count-size..<vals.count])
            }
            
            queue.replaceValues(vals)
            
            bufferMutated()
            
            if notify {
                sendUpdateNotification()
            }
        }
    }
    
    func append(_ value: Double?, async: Bool = false, notify: Bool = true) {
        if !staticBuffer || !written {
            if (value == nil) {
                return
            }
            
            written = true
            
            let operations = {
                self.queue.enqueue(value!, async: true)
                
                if (self.actualCount > self.size && self.size > 0) {
                    _ = self.queue.dequeue(true)
                    self.trashedCount += 1
                }
            }
            
            if async {
                operations()
            }
            else {
                queue.sync {
                    autoreleasepool(invoking: operations)
                }
            }
            
            bufferMutated()
            
            if notify {
                sendUpdateNotification()
            }
        }
    }
    
    func appendFromArray(_ values: [Double], notify: Bool = true) {
        if values.count == 0 {
            return
        }
        
        if !staticBuffer || !written {
            written = true
            
            queue.sync {
                autoreleasepool {
                    var array = self.queue.toArray()
                    
                    let afterSize = array.count+values.count
                    
                    let cut = afterSize-self.size
                    
                    let cutAfter = cut > array.count
                    
                    if !cutAfter && cut > 0 && self.size > 0  {
                        array.removeFirst(cut)
                    }
                    
                    array.append(contentsOf: values)
                    
                    if cutAfter && cut > 0 && self.size > 0 {
                        array.removeFirst(cut)
                    }
                    
                    self.queue.replaceValues(array, async: true)
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
    
    var description: String {
        get {
            return "<\(type(of: self)): \(Unmanaged.passUnretained(self).toOpaque()): \(toArray())>"
        }
    }
}

extension DataBuffer: Equatable {
    static func ==(lhs: DataBuffer, rhs: DataBuffer) -> Bool {
        return lhs.name == rhs.name && lhs.size == rhs.size && lhs.toArray() == rhs.toArray()
    }
}
