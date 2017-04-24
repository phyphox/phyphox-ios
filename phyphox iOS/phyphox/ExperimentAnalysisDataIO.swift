//
//  ExperimentAnalysisDataIO.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

final class ExperimentAnalysisDataIO {
    fileprivate(set) var asString: String?
    
    fileprivate(set) var buffer: DataBuffer?
    fileprivate(set) var value: Double?
    
    fileprivate(set) var clear = true
    
    func getSingleValue() -> Double? {
        return value ?? buffer!.last
    }
    
    init(buffer: DataBuffer) {
        self.buffer = buffer
    }
    
    init(dictionary: NSDictionary, buffers: [String: DataBuffer]) throws {
        var typeIsValue = false
        var typeIsEmpty = false
        
        if let attributes = dictionary[XMLDictionaryAttributesKey] as? [String: AnyObject] {
            let str = stringFromXML(attributes, key: "as", defaultValue: "")
            
            if str != "" {
                asString = str
            }
            
            let type = stringFromXML(attributes, key: "type", defaultValue: "")
            
            if type == "value" {
                typeIsValue = true
            } else if type == "empty" {
                typeIsEmpty = true
            }
            
            clear = boolFromXML(attributes, key: "clear", defaultValue: true)
        }
        
        let text = dictionary[XMLDictionaryTextKey] as? String
        
        if typeIsValue {
            if text != nil {
                value = Double(text!)
            } else {
                throw SerializationError.invalidExperimentFile(message: "Error! Input or output tag missing reference.")
            }
        }
        else if !typeIsEmpty {
            if text != nil {
                buffer = buffers[text!]
            } else {
                throw SerializationError.invalidExperimentFile(message: "Error! Input or output tag missing reference.")
            }
        }
    }
}
