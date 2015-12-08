//
//  Queue.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

/**
 Thread safe Queue (FIFO). Can only be modified by calling `enqueue()`, `dequeue()` and `clear()`.
 */
final class Queue<Element> {
    private var array: [Element] = []
    private let lockQueue = dispatch_queue_create("de.rwth-aachen.phyohox.queue.lock", nil)
    
    var count: Int {
        get {
            return array.count
        }
    }
    
    func toArray() -> [Element]? {
        return array
    }
    
    func clear() {
        dispatch_sync(lockQueue) { () -> Void in
            self.array.removeAll()
        }
    }
    
    func enqueue(value: Element) {
        dispatch_sync(lockQueue) { () -> Void in
            self.array.append(value)
        }
    }
    
    func peek() -> Element? {
        return array.first
    }
	
    func dequeue() -> Element? {
        var element: Element? = nil
        
        dispatch_sync(lockQueue) { () -> Void in
            if self.array.count > 0 {
                element = self.array.removeFirst()
            }
        }
        
        return element
    }
    
    func itemAtIndex(index: Int) -> Element? {
        var element: Element? = nil
        
        dispatch_sync(lockQueue) { () -> Void in
            if index < self.array.count {
                element = self.array[index]
            }
        }
        
        return element
    }
	
	func isEmpty() -> Bool {
		return array.isEmpty
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
        return itemAtIndex(i)!
    }
}
