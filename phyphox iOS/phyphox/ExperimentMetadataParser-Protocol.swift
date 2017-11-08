//
//  ExperimentMetadataParser-Protocol.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
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

func boolFromXML(_ xml: [String: AnyObject]?, key: String, defaultValue: Bool) -> Bool {
    if xml == nil {
        return defaultValue
    }
    
    func stringToBool(_ string: String) -> Bool {
        if string == "1" || string.lowercased() == "true" || string.lowercased() == "yes" {
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

func stringFromXML(_ xml: [String: AnyObject]?, key: String, defaultValue: String) -> String {
    if xml == nil {
        return defaultValue
    }
    
    return xml![key] as? String ?? defaultValue // <=> (xml![key] != nil ? xml![key] as? String : defaultValue)
}

func intTypeFromXML<T:intNumberType>(_ xml: [String: AnyObject]?, key: String, defaultValue: T) -> T {
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

func floatTypeFromXML<T:floatNumberType>(_ xml: [String: AnyObject]?, key: String, defaultValue: T) -> T {
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

func CGFloatFromXML(_ xml: [String: AnyObject]?, key: String, defaultValue: CGFloat) -> CGFloat {
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

func textFromXML(_ xml: AnyObject) throws -> String {
    if let str = xml as? String {
        return str
    }
    else if let d = xml as? NSDictionary {
        return d[XMLDictionaryTextKey] as! String
    }
    else if let d = xml as? NSMutableArray {
        return d.lastObject! as! String
    }
    else {
        throw SerializationError.invalidExperimentFile(message: "Invalid input for text \(xml)")
    }
}

func UIColorFromXML(_ xml: [String: AnyObject]?, key: String, defaultValue: UIColor) throws -> UIColor {
    if xml == nil {
        return defaultValue
    }
    
    if let str = xml![key] as? String {
        if str.characters.count != 6 {
            throw SerializationError.invalidExperimentFile(message: "Invalid color: \(str)")
        }
        
        var hex: UInt32 = 0
        Scanner(string: str).scanHexInt32(&hex)
        
        let r = CGFloat((hex & 0xff0000) >> 16)/255.0
        let g = CGFloat((hex & 0xff00) >> 8)/255.0
        let b = CGFloat((hex & 0xff) >> 0)/255.0
        
        return UIColor(red: r, green: g, blue: b, alpha: 1)
    }
    return defaultValue
}

//MARK: - Protocol

protocol ExperimentMetadataParser {
    associatedtype Input
    
    init(_ data: Input)
}
