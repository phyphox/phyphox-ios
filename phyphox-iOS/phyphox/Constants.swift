//
//  Constants.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
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

let kBackgroundColor = UIColor(white: 32.0/255.0, alpha: 1.0)
let kDarkBackgroundColor = UIColor(white: 16.0/255.0, alpha: 1.0)
let kLightBackgroundColor = UIColor(white: 64.0/255.0, alpha: 1.0)
let kLightBackgroundColorForLight = UIColor(white: 225.0/255.0, alpha: 1.0)
let kFullWhiteColor = UIColor(white: 255.0/255.0, alpha: 1.0)
let kLightGrayColor = UIColor(white: 0.8, alpha: 1.0)
let kLightBackgroundHoverColor = UIColor(white: 0.5, alpha: 1.0)
let kHighlightColor = UIColor(red: (255.0/255.0), green: (126.0/255.0), blue: (34.0/255.0), alpha: 1.0)
let kTextColor = UIColor(white: 1.0, alpha: 1.0)
let kText2Color = UIColor(white: 0.88, alpha: 1.0)
let kTextColorDeactivated = UIColor(white: 0.5, alpha: 1.0)

let kRWTHBackgroundColor = UIColor(white: 1.0, alpha: 1.0)
let kRWTHTextColor = UIColor(white: 0.0, alpha: 1.0)
let kRWTHBlue = UIColor(red: (0.0/255.0), green: (84.0/255.0), blue: (159.0/255.0), alpha: 1.0)
let kBluetooth = UIColor(red: (34.0/255.0), green: (96.0/255.0), blue: (165.0/255.0), alpha: 1.0)

let kDarkenedColor = UIColor(white: 0.0, alpha: 0.5)

let namedColors = [
    "orange":  UIColor(red: (255.0/255.0), green: (126.0/255.0), blue:  (34.0/255.0), alpha: 1.0),
    "red":     UIColor(red: (254.0/255.0), green:   (0.0/255.0), blue:  (93.0/255.0), alpha: 1.0),
    "magenta": UIColor(red: (235.0/255.0), green:  (70.0/255.0), blue: (244.0/255.0), alpha: 1.0),
    "blue":    UIColor(red:  (57.0/255.0), green: (162.0/255.0), blue: (255.0/255.0), alpha: 1.0),
    "green":   UIColor(red:  (43.0/255.0), green: (251.0/255.0), blue:  (76.0/255.0), alpha: 1.0),
    "yellow":  UIColor(red: (237.0/255.0), green: (246.0/255.0), blue: (104.0/255.0), alpha: 1.0),
    "white":   UIColor(red: (255.0/255.0), green: (255.0/255.0), blue: (255.0/255.0), alpha: 1.0),
    
    "weakorange":  UIColor(red: (255.0/255.0), green: (195.0/255.0), blue: (153.0/255.0), alpha: 1.0),
    "weakred":     UIColor(red: (255.0/255.0), green: (124.0/255.0), blue: (172.0/255.0), alpha: 1.0),
    "weakmagenta": UIColor(red: (246.0/255.0), green: (170.0/255.0), blue: (250.0/255.0), alpha: 1.0),
    "weakblue":    UIColor(red: (157.0/255.0), green: (209.0/255.0), blue: (255.0/255.0), alpha: 1.0),
    "weakgreen":   UIColor(red: (161.0/255.0), green: (253.0/255.0), blue: (175.0/255.0), alpha: 1.0),
    "weakyellow":  UIColor(red: (231.0/255.0), green: (224.0/255.0), blue: (155.0/255.0), alpha: 1.0),
    "weakwhite":   UIColor(red: (196.0/255.0), green: (196.0/255.0), blue: (196.0/255.0), alpha: 1.0)
]

let shutters = [1, 2, 4, 8, 15, 30, 60, 125, 250, 500, 1000, 2000, 4000, 8000]

let iso = [25, 50, 100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600, 51200]

func mapColorString(_ string: String?) -> UIColor? {
    guard let colorString = string else {
        return nil
    }
    
    if let color = namedColors[colorString.lowercased()] {
        return  color
    } else if let color = UIColor(hexString: colorString) {
        return color
    } else {
        return nil
    }
}

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
func after(_ delay: TimeInterval, body: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: body)
}

extension RangeReplaceableCollection {
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

