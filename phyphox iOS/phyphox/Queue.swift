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
    private let lockQueue = DispatchQueue(label: "de.j-gessner.queue.lock", attributes: [])
    
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
    
    init<S : Sequence>(_ sequence: S) where S.Iterator.Element == Element {
        array = Array(sequence)
    }
    
    func toArray() -> [Element] {
        return array
    }
    
    func sync(_ closure: (() -> Void)) {
        lockQueue.sync(execute: closure)
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
    
    func objectAtIndex(_ index: Int, async: Bool = false) -> Element? {
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
    func enqueue(_ value: Element, async: Bool = false) {
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
    
    func dequeue(_ async: Bool = false) -> Element? {
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
    
    func replaceValues(_ values: [Element], async: Bool = false) {
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

extension Queue: Sequence {
    typealias Iterator = IndexingIterator<[Element]>
    
    func makeIterator() -> Iterator {
        return array.makeIterator()
    }
}

extension Queue: Collection {

    typealias Index = Int
    
    func index(after i: Int) -> Int {
        return i+1
    }
    
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
