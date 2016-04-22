//
//  DataBuffer.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

protocol DataBufferObserver : AnyObject {
    func dataBufferUpdated(buffer: DataBuffer)
}

func ==(lhs: DataBuffer, rhs: DataBuffer) -> Bool {
    return lhs.name == rhs.name && lhs.size == rhs.size && lhs.toArray() == rhs.toArray()
}

/**
 Data buffer used for raw or processed data from sensors.
 */
final class DataBuffer: SequenceType, CustomStringConvertible, Hashable {
    let name: String
    var size: Int {
        didSet {
            while count > size {
                queue.dequeue()
            }
        }
    }
    
    var attachedToTextField = false
    
    var hashValue: Int {
        return name.hash
    }

    private var stateToken: NSUUID?
    
    private var observers = NSMutableOrderedSet()
    
    /**
     Notifications are sent in order, first registered, first notified.
     */
    func addObserver(observer: DataBufferObserver) {
        observers.addObject(observer)
    }
    
    func removeObserver(observer: DataBufferObserver) {
        observers.removeObject(observer)
    }
    
    /**
     A state token represents a state of the data contained in the buffer. Whenever the data in the buffer changes the current state token gets invalidated.
     */
    func getStateToken() -> NSUUID? {
        if stateToken == nil {
            stateToken = NSUUID()
        }
        
        return stateToken
    }
    
    func stateTokenIsValid(token: NSUUID?) -> Bool {
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
            return Swift.min(queue.count, size)
        }
    }
    
    var actualCount: Int {
        get {
            return queue.count
        }
    }
    
    private let queue: Queue<Double>
    
    init(name: String, size: Int) {
        self.name = name
        self.size = size
        queue = Queue<Double>(capacity: size)
    }
    
    func generate() -> IndexingGenerator<[Double]> {
        return queue.generate()
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
    
    func sendUpdateNotification() {
        for observer in observers {
            mainThread {
                (observer as! DataBufferObserver).dataBufferUpdated(self)
            }
        }
    }
    
    subscript(index: Int) -> Double {
        get {
            return queue[index]
        }
    }
    
    func objectAtIndex(index: Int, async: Bool = false) -> Double? {
        return queue.objectAtIndex(index, async: async)
    }
    
    func clear(notify: Bool = true) {
        queue.clear()
        trashedCount = 0
        written = false
        
        bufferMutated()
        
        if notify {
            sendUpdateNotification()
        }
    }
    
    func replaceValues(values: [Double], notify: Bool = true) {
        if !staticBuffer || !written {
            written = true
            trashedCount = 0
            
            var vals = values
            
            if vals.count > size {
                vals = Array(vals[vals.count-size..<vals.count])
            }
            
            queue.replaceValues(vals)
            
            bufferMutated()
            
            if notify {
                sendUpdateNotification()
            }
        }
    }
    
    func append(value: Double?, async: Bool = false, notify: Bool = true) {
        if !staticBuffer || !written {
            if (value == nil) {
                return
            }
            
            written = true
            
            let operations = {
                self.queue.enqueue(value!, async: true)
                
                if (self.actualCount > self.size) {
                    self.queue.dequeue(true)
                    self.trashedCount += 1
                }
            }
            
            if async {
                operations()
            }
            else {
                queue.sync {
                    autoreleasepool(operations)
                }
            }
            
            bufferMutated()
            
            if notify {
                sendUpdateNotification()
            }
        }
    }
    
    func appendFromArray(values: [Double], notify: Bool = true) {
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
                    
                    if !cutAfter && cut > 0  {
                        array.removeFirst(cut)
                    }
                    
                    array.appendContentsOf(values)
                    
                    if cutAfter && cut > 0 {
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
            return "<\(self.dynamicType): \(unsafeAddressOf(self)): \(toArray())>"
        }
    }
}
