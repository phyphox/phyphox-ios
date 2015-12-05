//
//  DataBuffer.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

/**
Queue Item.
*/
class QueueItem<T> {
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
public class Queue<Element>: SequenceType {
	private(set) var head: QueueItem<Element>
	private(set) var tail: QueueItem<Element>
    private(set) var count: UInt64 = 0
    
    public init() {
        tail = QueueItem(nil)
        head = tail
    }
    
    public func generate() -> AnyGenerator<Element> {
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
    
    public func toArray() -> [Element]? {
        var array: [Element] = []
        
        for value in self {
            array.append(value)
        }
        
        return array.count > 0 ? array : nil
    }
    
    public func clear() {
        tail = QueueItem(nil)
        head = tail
        count = 0
    }
	
	public func enqueue(value: Element) {
		tail.next = QueueItem(value)
		tail = tail.next!
        count++
	}
	
	public func dequeue() -> Element? {
		if let newhead = head.next {
			head = newhead
            count--
			return newhead.value
		}
        else {
			return nil
		}
	}
	
	public func isEmpty() -> Bool {
		return head === tail
	}
}
