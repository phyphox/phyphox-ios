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

/**
 Data buffer used for raw or processed data from sensors.
 */
@objc final class DataBuffer: NSObject, SequenceType {
    let name: String
    var size: Int {
        didSet {
            while count > size {
                queue.dequeue()
            }
        }
    }
    
    private var observers: NSMutableOrderedSet = NSMutableOrderedSet()
    
    /**
     Notifications are sent in order, first registered, first notified.
     */
    func addObserver(observer: DataBufferObserver) {
        observers.addObject(observer)
    }
    
    func removeObserver(observer: DataBufferObserver) {
        observers.removeObject(observer)
    }
    
    private class DataBufferGraphValueSource: GraphValueSource {
        weak var buffer: DataBuffer!
        
        init(buffer: DataBuffer) {
            self.buffer = buffer
        }
        
        subscript(index: Int) -> Double? {
            return buffer.objectAtIndex(index)
        }
        
        var last: Double? {
            get {
                return buffer.last
            }
        }
        
        var count: Int {
            get {
                return buffer.count
            }
        }
    }
    
    var graphValueSource: GraphValueSource!
    
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
        super.init()
        graphValueSource = DataBufferGraphValueSource(buffer: self)
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
            (observer as! DataBufferObserver).dataBufferUpdated(self)
        }
    }
    
    /**
     Async
     */
    subscript(index: Int) -> Double {
        get {
            return queue[index]
        }
    }
    
    /**
     Synchronized
     */
    func objectAtIndex(index: Int, async: Bool = false) -> Double? {
        return queue.objectAtIndex(index, async: async)
    }
    
    func clear() {
        if (!staticBuffer) {
            queue.clear()
            trashedCount = 0
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
            
            if notify {
                sendUpdateNotification()
            }
        }
    }
    
    func append(value: Double?, async: Bool = false, notify: Bool = true) {
        if !staticBuffer || !written {
            written = true
            if (value == nil) {
                return
            }
            
            let operations = { () -> () in
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
                queue.sync {() -> Void in
                    autoreleasepool(operations)
                }
            }
            
            if notify {
                sendUpdateNotification()
            }
        }
    }
    
    func appendFromArray(values: [Double], notify: Bool = true) {
        if !staticBuffer || !written {
            written = true
            queue.sync({ () -> Void in
                autoreleasepool({ () -> () in
                    var array = self.queue.toArray()
                    
                    array.appendContentsOf(values)
                    
                    if array.count > self.size {
                        array = Array(array[array.count-self.size..<array.count])
                    }
                    
                    self.queue.replaceValues(values, async: true)
                })
            })
            
            if notify {
                sendUpdateNotification()
            }
        }
    }
    
    func toArray() -> [Double] {
        return queue.toArray()
    }
    
    override var description: String {
        get {
            return "<\(self.dynamicType): \(unsafeAddressOf(self)): \(toArray())>"
        }
    }
}
