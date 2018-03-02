//
//  Queue.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

struct Queue<Element> {
    private var array: [Element]
    
    var count: Int {
        return array.count
    }
    
    var capacity: Int {
        return array.capacity
    }
    
    var isEmpty: Bool {
        return array.isEmpty
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

    var first: Element? {
        return array.first
    }

    var last: Element? {
        return array.last
    }

    func objectAtIndex(_ index: Int) -> Element? {
        var element: Element? = nil
        
        if index < self.array.count {
            element = self.array[index]
        }
        
        return element
    }
}

//MARK - Mutation

extension Queue {
    mutating func enqueue(_ value: Element) {
        array.append(value)
    }

    mutating func enqueue(_ values: [Element]) {
        array.append(contentsOf: values)
    }

    mutating func removeFirst(_ n: Int) {
        array.removeFirst(Swift.min(n, count))
    }
    
    mutating func dequeue() -> Element? {
        if self.array.count > 0 {
            return array.removeFirst()
        }

        return nil
    }
    
    mutating func clear() {
        array.removeAll()
    }
    
    mutating func replaceValues(_ values: [Element]) {
        array = values
    }
}

//MARK - Protocol Conformance

extension Queue: Sequence {
    typealias Iterator = IndexingIterator<[Element]>
    
    func makeIterator() -> Iterator {
        return array.makeIterator()
    }
}

extension Queue: Collection {
    typealias Index = Int
    
    func index(after i: Int) -> Int {
        return i + 1
    }
    
    var startIndex: Int {
        return 0
    }
    
    var endIndex: Int {
        return count
    }
    
    subscript(i: Int) -> Element {
        return array[i]
    }
}

extension Queue: CustomStringConvertible {
    var description: String {
        return array.description
    }
}
