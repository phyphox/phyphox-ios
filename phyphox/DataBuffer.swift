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
    
    func append(value: Double!) {
        if (value == nil) {
            return
        }
        
        queue.sync {() -> Void in
            autoreleasepool({ () -> () in
                if (self.count >= self.size) {
                    self.queue.dequeue_async()
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
                
                self.queue.enqueue_async(value)
            })
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
    
    func appendFromArray(values: [Double]) {
        for value in values {
            append(value)
        }
    }
    
    func toArray() -> [Double] {
        return queue.toArray()
    }
}
