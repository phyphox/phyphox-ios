//
//  Queue.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

/**
 Thread safe Queue (FIFO).
 */
final class Queue<Element> {
    private let lockQueue = dispatch_queue_create("de.j-gessner.queue.lock", DISPATCH_QUEUE_SERIAL)
    
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
        array = Array(sequence)
    }
    
    func toArray() -> [Element] {
        return array
    }
    
    func sync(closure: (() -> Void)) {
        dispatch_sync(lockQueue, closure)
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
    
    func objectAtIndex(index: Int, async: Bool = false) -> Element? {
        var element: Element? = nil
        
        let op = { [unowned self] in
            autoreleasepool{
                if index < self.array.count {
                    element = self.array[index]
                }
            }
        }
        
        if async {
            op()
        }
        else {
            sync(op)
        }
        
        return element
    }
}

//MARK - Mutating

extension Queue {
    func enqueue(value: Element, async: Bool = false) {
        let op = {
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
        
        let op = { [unowned self] in
            autoreleasepool{
                if self.array.count > 0 {
                    element = self.array.removeFirst()
                }
            }
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
        let op = { [unowned self] in
            self.array = values
        }
        
        if async {
            op()
        }
        else {
            sync(op)
        }
    }
}

//MARK - Protocols

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
        
        sync { [unowned self] in
            autoreleasepool{
                value = self.array[i]
            }
        }
        
        return value
    }
}
