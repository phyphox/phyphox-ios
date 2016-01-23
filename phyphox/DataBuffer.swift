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
        
        subscript(index: Int) -> Double {
            return buffer[index]
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
    
    //Special purpose setter for max and min. The graph view iterates through all values anyway, so that can be used to calculate the max and min values (which will take effect on the next redraw of the graph).
    func updateMaxAndMin(max: Double?, min: Double?) {
        self.max = max
        self.min = min
    }
    
    var trashedCount: Int = 0
    
    var staticBuffer: Bool = false
    var count: Int {
        get {
            return Swift.min(queue.count, size)
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
    
    func append(value: Double!, async: Bool = false) {
        if (value == nil) {
            return
        }
        
        let operations = { () -> () in
            if (self.count >= self.size) {
                self.queue.dequeue(true)
                self.trashedCount++
            }
            
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
        }
        
        if async {
            operations()
        }
        else {
            queue.sync {() -> Void in
                autoreleasepool(operations)
            }
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(DataBufferReceivedNewValueNotification, object: self, userInfo: nil)
    }
    
    subscript(index: Int) -> Double {
        get {
            return queue[index]
        }
    }
    
    func clear() {
        if (!staticBuffer) {
            queue.clear()
            max = nil
            min = nil
            trashedCount = 0
        }
    }
    
    /**
     max and min are not changed when calling this method. Manually updating max and min is required.
     */
    func replaceValues(values: [Double]) {
        if (!staticBuffer) {
            trashedCount = 0
            queue.replaceValues(values)
            NSNotificationCenter.defaultCenter().postNotificationName(DataBufferReceivedNewValueNotification, object: self, userInfo: nil)
        }
    }
    
    func appendFromArray(values: [Double]) {
        queue.sync {() -> Void in
            autoreleasepool({ () -> () in
                for value in values {
                    self.append(value, async: true)
                }
            })
        }
    }
    
    func toArray() -> [Double] {
        return queue.toArray()
    }
}
