//
//  Queue.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

private let lockQueue = dispatch_queue_create("de.rwth-aachen.phyohox.queue.lock", DISPATCH_QUEUE_SERIAL)

/**
 Thread safe Queue (FIFO).
 */
final class Queue<Element> {
    private var array: [Element]
    
    var count: Int {
        get {
            return array.count
        }
    }
    
    var isEmpty: Bool {
        get {
            return array.isEmpty
        }
    }
    
    init() {
        array = []
    }
    
    init(capacity: Int) {
        array = []
        array.reserveCapacity(capacity)
    }
    
    init<S : SequenceType where S.Generator.Element == Element>(_ sequence: S) {
        array = Array<Element>(sequence)
    }
    
    func toArray() -> [Element] {
        return array
    }
    
    func enqueue(value: Element) {
        dispatch_sync(lockQueue) { () -> Void in
            autoreleasepool({ () -> () in
                self.array.append(value)
            })
        }
    }
    
    func dequeue() -> Element? {
        var element: Element? = nil
        
        dispatch_sync(lockQueue) { () -> Void in
            autoreleasepool({ () -> () in
                if self.array.count > 0 {
                    element = self.array.removeFirst()
                }
            })
        }
        
        return element
    }
    
    func clear() {
        dispatch_sync(lockQueue) { () -> Void in
            autoreleasepool({ () -> () in
                self.array.removeAll()
            })
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
        
        dispatch_sync(lockQueue) { () -> Void in
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
        
        dispatch_sync(lockQueue) { () -> Void in
            autoreleasepool({ () -> () in
                value = self.array[i]
            })
        }
        
        return value
    }
}
