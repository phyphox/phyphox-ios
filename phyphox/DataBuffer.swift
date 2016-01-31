//
//  DataBuffer.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

let DataBufferReceivedNewValueNotification = "DataBufferReceivedNewValueNotification"

/**
 Data buffer used for raw or processed data from sensors.
 */
final class DataBuffer: NSObject, SequenceType {
    let name: String
    var size: Int {
        didSet {
            while count > size {
                queue.dequeue()
            }
        }
    }
    
    private class DataBufferGraphValueSource: JGGraphValueSource {
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
    
    var graphValueSource: JGGraphValueSource!
    
    private(set) var max: Double? = nil
    private(set) var min: Double? = nil
    
    /**
     Special purpose setter for max and min. The graph view iterates through all values anyway, so that can be used to calculate the max and min values (which will take effect on the next redraw of the graph).
     */
    func updateMaxAndMin(max: Double?, min: Double?, compare: Bool = false) {
        if compare {
            if self.max == nil {
                self.max = max
            }
            else {
                if max != nil {
                    self.max = Swift.max(self.max!, max!)
                }
            }
            
            if self.min == nil {
                self.min = min
            }
            else {
                if min != nil {
                    self.min = Swift.min(self.min!, min!)
                }
            }
        }
        else {
            self.max = max
            self.min = min
        }
    }
    
    var trashedCount: Int = 0
    
    var staticBuffer: Bool = false
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
    
    func append(value: Double!, async: Bool = false, notify: Bool = true) {
        if (value == nil) {
            return
        }
        
        let operations = { () -> () in
            if self.max == nil {
                self.max = value
            }
            else {
                self.max = Swift.max(self.max!, value)
            }
            
            if self.min == nil {
                self.min = value
            }
            else {
                self.min = Swift.min(self.min!, value)
            }
            
            self.queue.enqueue(value, async: true)
            
            if (self.actualCount > self.size) {
                self.queue.dequeue(true)
                self.trashedCount++
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
    
    func sendUpdateNotification() {
        NSNotificationCenter.defaultCenter().postNotificationName(DataBufferReceivedNewValueNotification, object: self, userInfo: nil)
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
            max = nil
            min = nil
            trashedCount = 0
        }
    }
    
    func replaceValues(var values: [Double], max: Double?, min: Double?, notify: Bool = true) {
        if (!staticBuffer) {
            updateMaxAndMin(max, min: min)
            
            trashedCount = 0
            
            if values.count > size {
                values = Array(values[values.count-size..<values.count])
            }
            
            queue.replaceValues(values)
            
            if notify {
                sendUpdateNotification()
            }
        }
    }
    
    /**
     Passing `false` for `iterative` will increase performance, but max and min values will not be updated. They will have to be updated manually.
     */
    func appendFromArray(values: [Double], iterative: Bool = true, notify: Bool = true) {
        if iterative {
            queue.sync {() -> Void in
                autoreleasepool({ () -> () in
                    for value in values {
                        self.append(value, async: true, notify: false)
                    }
                })
            }
        }
        else {
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
        }
        
        if notify {
            sendUpdateNotification()
        }
    }
    
    func toArray() -> [Double] {
        return queue.toArray()
    }
}
