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

protocol floatNumberType {
    init?(_: String)
}

protocol intNumberType {
    init?(_ text: String, radix: Int)
}

extension Double: floatNumberType {}
extension Float: floatNumberType {}

extension Int: intNumberType {}
extension Int32: intNumberType {}
extension Int64: intNumberType {}
extension UInt: intNumberType {}
extension UInt32: intNumberType {}
extension UInt64: intNumberType {}

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

func intTypeFromXML<T:intNumberType>(xml: [String: AnyObject]?, key: String, defaultValue: T) -> T {
    if xml == nil {
        return defaultValue
    }
    
    if let str = xml![key] as? String {
        if let d = T(str, radix: 10) {
            return d
        }
    }
    return defaultValue
}

func floatTypeFromXML<T:floatNumberType>(xml: [String: AnyObject]?, key: String, defaultValue: T) -> T {
    if xml == nil {
        return defaultValue
    }
    
    if let str = xml![key] as? String {
        if let d = T(str) {
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

//MARK: - Protocol

protocol ExperimentMetadataParser {
    typealias Input
    
    init(_ data: Input)
}
