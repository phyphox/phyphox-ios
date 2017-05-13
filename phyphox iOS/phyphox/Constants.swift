//
//  Constants.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit
import Foundation
import CoreGraphics
import Accelerate
import AudioToolbox

func CGRectGetMid(_ r: CGRect) -> CGPoint {
    return CGPoint(x: r.midX, y: r.midY)
}

let iPad = UI_USER_INTERFACE_IDIOM() == .pad

let kBackgroundColor = UIColor(white: 0.25, alpha: 1.0)
let kDarkBackgroundColor = UIColor(white: 0.12, alpha: 1.0)
let kLightBackgroundColor = UIColor(white: 0.37, alpha: 1.0)
let kLightBackgroundHoverColor = UIColor(white: 0.5, alpha: 1.0)
let kHighlightColor = UIColor(red: (255.0/255.0), green: (126.0/255.0), blue: (34.0/255.0), alpha: 1.0)
let kTextColor = UIColor(white: 1.0, alpha: 1.0)
let kText2Color = UIColor(white: 0.88, alpha: 1.0)
let kTextColorDeactivated = UIColor(white: 0.5, alpha: 1.0)

let kRWTHBackgroundColor = UIColor(white: 1.0, alpha: 1.0)
let kRWTHTextColor = UIColor(white: 0.0, alpha: 1.0)
let kRWTHBlue = UIColor(red: (0.0/255.0), green: (84.0/255.0), blue: (159.0/255.0), alpha: 1.0)

let kDarkenedColor = UIColor(white: 0.0, alpha: 0.5)

/**
Runs a closure on the main thread.
*/
func mainThread(_ closure: @escaping () -> Void) {
    if Thread.isMainThread {
        closure()
    }
    else {
        DispatchQueue.main.async(execute: closure)
    }
}

/**
The closure is executed after the given delay on the main thread.
*/
func after(_ delay: TimeInterval, closure: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(Double(NSEC_PER_SEC)*delay)) / Double(NSEC_PER_SEC), execute: closure)
}

extension RangeReplaceableCollection where Index : Comparable{
    mutating func removeAtIndices<S : Sequence>(_ indices: S) where S.Iterator.Element == Index {
        indices.sorted().lazy.reversed().forEach{ remove(at: $0) }
    }
}

func monoFloatFormatWithSampleRate(_ sampleRate: Double) -> AudioStreamBasicDescription {
    let byteSize = UInt32(MemoryLayout<Float>.size)
    
    return AudioStreamBasicDescription(mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsPacked|kAudioFormatFlagIsFloat, mBytesPerPacket: byteSize, mFramesPerPacket: 1, mBytesPerFrame: byteSize, mChannelsPerFrame: 1, mBitsPerChannel: UInt32(CHAR_BIT)*byteSize, mReserved: 0)
}

func generateDots(_ height: CGFloat) -> UIImage {
    let d = height/5.0
    let r = d/2.0
    
    UIGraphicsBeginImageContextWithOptions(CGSize(width: d, height: height), false, 0.0)
    
    let path = UIBezierPath(arcCenter: CGPoint(x: r, y: r), radius: r, startAngle: 0.0, endAngle: CGFloat(2.0*Double.pi), clockwise: true)
    
    path.addArc(withCenter: CGPoint(x: r, y: r+2.0*d), radius: r, startAngle: 0.0, endAngle: CGFloat(2.0*Double.pi), clockwise: true)
    
    path.addArc(withCenter: CGPoint(x: r, y: r+4.0*d), radius: r, startAngle: 0.0, endAngle: CGFloat(2.0*Double.pi), clockwise: true)
    
    path.fill()
    
    let img = UIGraphicsGetImageFromCurrentImageContext()!.withRenderingMode(.alwaysTemplate)
    
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

func queryDictionary(_ query: String) -> [String: String] {
    var dict = [String: String]()
    
    for item in query.components(separatedBy: "&") {
        let c = item.components(separatedBy: "=")
        
        if c.count > 1 {
            dict[c.first!] = c.last!
        }
        else {
            dict[c.first!] = ""
        }
    }
    
    return dict
}
