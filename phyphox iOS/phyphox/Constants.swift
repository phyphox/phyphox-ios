//
//  Constants.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import UIKit
import Foundation
import CoreGraphics
import Accelerate
import AudioToolbox

func CGRectGetMid(r: CGRect) -> CGPoint {
    return CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r))
}

let iPad = UI_USER_INTERFACE_IDIOM() == .Pad

let kBackgroundColor = UIColor(white: 0.95, alpha: 1.0)
let kLightBackgroundColor = UIColor(white: 0.975, alpha: 1.0)
let kHighlightColor = UIColor(red: (226.0/255.0), green: (67.0/255.0), blue: (48.0/255.0), alpha: 1.0)

infix operator =-= { associativity left }
infix operator !=-= { associativity left }
/**
 Compare optionals.
 - Note: Returns true for a == nil and b == nil.
 */
func =-= <T: Equatable>(a: T?, b: T?) -> Bool {
    if a == nil && b != nil || b == nil && a != nil {
        return false
    }
    else if a == nil && b == nil {
        return true
    }
    
    return a! == b!
}

func !=-= <T: Equatable>(a: T?, b: T?) -> Bool {
    return !(a =-= b)
}

/**
Runs a closure on the main thread.
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

extension RangeReplaceableCollectionType where Index : Comparable{
    mutating func removeAtIndices<S : SequenceType where S.Generator.Element == Index>(indices: S) {
        indices.sort().lazy.reverse().forEach{ removeAtIndex($0) }
    }
}

func monoFloatFormatWithSampleRate(sampleRate: Double) -> AudioStreamBasicDescription {
    let byteSize = UInt32(sizeof(Float))
    
    return AudioStreamBasicDescription(mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsPacked|kAudioFormatFlagIsFloat, mBytesPerPacket: byteSize, mFramesPerPacket: 1, mBytesPerFrame: byteSize, mChannelsPerFrame: 1, mBitsPerChannel: UInt32(CHAR_BIT)*byteSize, mReserved: 0)
}

func generateDots(height: CGFloat) -> UIImage {
    let d = height/5.0
    let r = d/2.0
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(d, height), false, 0.0)
    
    let path = UIBezierPath(arcCenter: CGPointMake(r, r), radius: r, startAngle: 0.0, endAngle: CGFloat(2.0*M_PI), clockwise: true)
    
    path.addArcWithCenter(CGPointMake(r, r+2.0*d), radius: r, startAngle: 0.0, endAngle: CGFloat(2.0*M_PI), clockwise: true)
    
    path.addArcWithCenter(CGPointMake(r, r+4.0*d), radius: r, startAngle: 0.0, endAngle: CGFloat(2.0*M_PI), clockwise: true)
    
    path.fill()
    
    let img = UIGraphicsGetImageFromCurrentImageContext().imageWithRenderingMode(.AlwaysTemplate)
    
    UIGraphicsEndImageContext()
    
    return img
}

#if DEBUG
func measure(label: String? = nil, closure: () -> Void) {
    let start = CFAbsoluteTimeGetCurrent()
    
    closure()
    
    let t = CFAbsoluteTimeGetCurrent()-start
    
    print("\(label ?? "measurement") took: \(t)")
}
#endif

func queryDictionary(query: String) -> [String: String] {
    var dict = [String: String]()
    
    for item in query.componentsSeparatedByString("&") {
        let c = item.componentsSeparatedByString("=")
        
        if c.count > 1 {
            dict[c.first!] = c.last!
        }
        else {
            dict[c.first!] = ""
        }
    }
    
    return dict
}
