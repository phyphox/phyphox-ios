//
//  ExperimentMetadataParser-Protocol.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreGraphics

//MARK: Parsing helpers

func boolFromXML(xml: [String: AnyObject]?, key: String, defaultValue: Bool) -> Bool {
    if xml == nil {
        return defaultValue
    }
    
    func stringToBool(string: String) -> Bool {
        if string == "1" || string.lowercaseString == "true" || string.lowercaseString == "yes" {
            return true
        }
        
        return false
    }
    
    if let str = xml![key] as? String {
        return stringToBool(str)
    }
    else {
        return defaultValue
    }
}

func stringFromXML(xml: [String: AnyObject]?, key: String, defaultValue: String) -> String {
    if xml == nil {
        return defaultValue
    }
    
    if let str = xml![key] as? String {
        return str
    }
    else {
        return defaultValue
    }
}

func doubleFromXML(xml: [String: AnyObject]?, key: String, defaultValue: Double) -> Double {
    if xml == nil {
        return defaultValue
    }
    
    if let str = xml![key] as? String {
        if let d = Double(str) {
            return d
        }
    }
    return defaultValue
}

func floatFromXML(xml: [String: AnyObject]?, key: String, defaultValue: Float) -> Float {
    if xml == nil {
        return defaultValue
    }
    
    if let str = xml![key] as? String {
        if let d = Float(str) {
            return d
        }
    }
    return defaultValue
}

func CGFloatFromXML(xml: [String: AnyObject]?, key: String, defaultValue: CGFloat) -> CGFloat {
    if xml == nil {
        return defaultValue
    }
    
    if let str = xml![key] as? String {
        if let d = CGFloat.NativeType(str) {
            return CGFloat(d)
        }
    }
    return defaultValue
}

func intFromXML(xml: [String: AnyObject]?, key: String, defaultValue: Int) -> Int {
    if xml == nil {
        return defaultValue
    }
    
    if let str = xml![key] as? String {
        if let i = Int(str) {
            return i
        }
    }
    return defaultValue
}

func uintFromXML(xml: [String: AnyObject]?, key: String, defaultValue: UInt) -> UInt {
    if xml == nil {
        return defaultValue
    }
    
    if let str = xml![key] as? String {
        if let i = UInt(str) {
            return i
        }
    }
    return defaultValue
}

//MARK: - Protocol

protocol ExperimentMetadataParser {
    typealias Input
    typealias Output
    
    init(_ data: Input)
    
    func parse() -> Output
}
