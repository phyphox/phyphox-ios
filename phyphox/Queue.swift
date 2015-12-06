//
//  DataBuffer.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

//FIXME: This class needs to be tested.

/**
Queue Item.
*/
final class QueueItem<T> {
	let value: T?
	private(set) var next: QueueItem?
	
	init(_ value: T?) {
		self.value = value
	}
    
    deinit {
        
    }
}

/**
 Queue (FIFO). Not thread safe! Can only be modified by calling `enqueue()`, `dequeue()` and `clear()`.
 */
final class Queue<Element>: SequenceType {
	private(set) var head: QueueItem<Element>
	private(set) var tail: QueueItem<Element>
    private(set) var count: UInt64 = 0
    
    init() {
        tail = QueueItem(nil)
        head = tail
    }
    
    func generate() -> AnyGenerator<Element> {
        var element = head as QueueItem<Element>?
        
        return anyGenerator {
            if (element == nil || element!.value == nil) {
                return nil
            }
            
            let val = element!.value!
            
            element = element!.next
            
            return val
        }
    }
    
    func toArray() -> [Element]? {
        var array: [Element] = []
        
        for value in self {
            array.append(value)
        }
        
        return array.count > 0 ? array : nil
    }
    
    func clear() {
        tail = QueueItem(nil)
        head = tail
        count = 0
    }
	
	func enqueue(value: Element) {
		tail.next = QueueItem(value)
		tail = tail.next!
        count++
	}
	
	func dequeue() -> Element? {
		if let newhead = head.next {
			head = newhead
            count--
			return newhead.value
		}
        else {
			return nil
		}
	}
    
    func itemAtIndex(index: UInt64) -> Element? {
        var i = UInt64(0)
        var item = head as QueueItem?
        
        while item !== nil {
            if i == index {
                return item!.value
            }
            
            item = item!.next
            i++
        }
        
        return nil
    }
	
	func isEmpty() -> Bool {
		return head === tail
	}
}
