//
//  Queue.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

/**
 Thread safe Queue (FIFO).
 */
final class Queue<Element> {
    private let lockQueue = dispatch_queue_create("de.rwth-aachen.phyohox.queue.lock", DISPATCH_QUEUE_SERIAL)
    
    private var array: [Element]
    
    var count: Int {
        get {
            return array.count
        }
    }
    
    var capacity: Int {
        get {
            return array.capacity
        }
    }
    
    var isEmpty: Bool {
        get {
            return array.isEmpty
        }
    }
    
    init(capacity: Int = 0) {
        array = []
        if capacity > 0 {
            array.reserveCapacity(capacity)
        }
    }
    
    init<S : SequenceType where S.Generator.Element == Element>(_ sequence: S) {
        array = Array<Element>(sequence)
    }
    
    func toArray() -> [Element] {
        return array
    }
    
    func sync(closure: (() -> Void)) {
        dispatch_sync(lockQueue, closure)
    }
    
    func enqueue(value: Element, async: Bool = false) {
        let op = { () -> Void in
            self.array.append(value)
        }
        
        if async {
            op()
        }
        else {
            sync(op)
        }
    }
    
    func dequeue(async: Bool = false) -> Element? {
        var element: Element? = nil
        
        let op = { () -> Void in
            autoreleasepool({ () -> () in
                if self.array.count > 0 {
                    element = self.array.removeFirst()
                }
            })
        }
        
        if async {
            op()
        }
        else {
            sync(op)
        }
        
        return element
    }
    
    func clear() {
        sync { () -> Void in
            self.array.removeAll()
        }
    }
    
    func replaceValues(values: [Element], async: Bool = false) {
        let op = { () -> Void in
            self.array = values
        }
        
        if async {
            op()
        }
        else {
            sync(op)
        }
    }
    
    var first: Element? {
        get {
            return array.first
        }
    }
    
    var last: Element? {
        get {
            return array.last
        }
    }
    
    func objectAtIndex(index: Int) -> Element? {
        var element: Element? = nil
        
        sync { () -> Void in
            autoreleasepool({ () -> () in
                if index < self.array.count {
                    element = self.array[index]
                }
            })
        }
        
        return element
    }
}

extension Queue: SequenceType {
    typealias Generator = IndexingGenerator<[Element]>
    
    func generate() -> Generator {
        return array.generate()
    }
}

extension Queue: CollectionType {
    typealias Index = Int
    
    var startIndex: Int {
        return 0
    }
    
    var endIndex: Int {
        return count
    }
    
    subscript(i: Int) -> Element {
        var value: Element!
        
        sync { () -> Void in
            autoreleasepool({ () -> () in
                value = self.array[i]
            })
        }
        
        return value
    }
}
