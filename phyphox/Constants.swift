//
//  Constants.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreGraphics

func CGRectGetMid(r: CGRect) -> CGPoint {
    return CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r))
}

/**
Runs a closure on the main thread, synchronically if the current thread is the main thread, otherwise asynchronically.
*/
func mainThread(closure: () -> Void) {
    if NSThread.isMainThread() {
        closure()
    }
    else {
        dispatch_async(dispatch_get_main_queue(), closure)
    }
}

/**
The closure is executed after the given delay on the main thread.
*/
func after(delay: NSTimeInterval, closure: () -> Void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(Double(NSEC_PER_SEC)*delay)), dispatch_get_main_queue(), closure)
}

extension RangeReplaceableCollectionType where Index : Comparable {
    mutating func removeAtIndices<S : SequenceType where S.Generator.Element == Index>(indices: S) {
        indices.sort().lazy.reverse().forEach{ removeAtIndex($0) }
    }
}
