//
//  DataBuffer.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

/**
 Data buffer used for raw or processed data from sensors.
 */
class DataBuffer: NSObject, SequenceType {
    let name: String
    var size: Int {
        didSet {
            while count > size {
                queue.dequeue()
            }
        }
    }
    var staticBuffer: Bool = false
    var count: Int {
        get {
            return queue.count
        }
    }
    
    private let queue: Queue<Double>
    
    init(name: String, size: Int) {
        self.name = name
        self.size = size
        queue = Queue<Double>()
        super.init()
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
            return;
        }
        
        if (count >= size) {
            queue.dequeue()
        }
        
        queue.enqueue(value)
    }
    
    subscript(index: Int) -> Double {
        get {
            return queue[index]
        }
    }
    
    func clear() {
        if (!staticBuffer) {
            queue.clear()
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
