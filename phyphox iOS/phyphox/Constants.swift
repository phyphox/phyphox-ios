//
//  Constants.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreGraphics
import Accelerate
import AudioToolbox

func CGRectGetMid(r: CGRect) -> CGPoint {
    return CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r))
}

let kBackgroundColor = UIColor(white: 0.95, alpha: 1.0)
let kHighlightColor = UIColor(red: (226.0/255.0), green: (67.0/255.0), blue: (48.0/255.0), alpha: 1.0)

var iOS9: Bool {
    return ptHelperFunctionIsIOS9()
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

func monoFloatFormatWithSampleRate(sampleRate: Double) -> AudioStreamBasicDescription {
    let byteSize = UInt32(sizeof(Float))
    
    return AudioStreamBasicDescription(mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsPacked|kAudioFormatFlagIsFloat, mBytesPerPacket: byteSize, mFramesPerPacket: 1, mBytesPerFrame: byteSize, mChannelsPerFrame: 1, mBitsPerChannel: UInt32(CHAR_BIT)*byteSize, mReserved: 0)
}

func measure(label: String? = nil, closure: () -> ()) {
    let start = CFAbsoluteTimeGetCurrent()
    
    closure()
    
    let t = CFAbsoluteTimeGetCurrent()-start
    
    print("\(label ?? "measurement") took: \(t)")
}

