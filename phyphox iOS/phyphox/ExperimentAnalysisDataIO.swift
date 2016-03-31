//
//  ExperimentAnalysisDataIO.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentAnalysisDataIO {
    private(set) var asString: String?
    
    private(set) var buffer: DataBuffer?
    private(set) var value: Double?
    
    private(set) var clear = true
    
    func getSingleValue() -> Double? {
        return value ?? buffer!.last
    }
    
    init(buffer: DataBuffer) {
        self.buffer = buffer
    }
    
    init(dictionary: NSDictionary, buffers: [String: DataBuffer]) {
        var typeIsValue = false
        
        if let attributes = dictionary[XMLDictionaryAttributesKey] as? [String: AnyObject] {
            let str = stringFromXML(attributes, key: "as", defaultValue: "")
            
            if str != "" {
                asString = str
            }
            
            let type = stringFromXML(attributes, key: "type", defaultValue: "")
            
            if type == "value" {
                typeIsValue = true
            }
            
            clear = boolFromXML(attributes, key: "clear", defaultValue: true)
        }
        
        let text = dictionary[XMLDictionaryTextKey] as! String
        
        if typeIsValue {
            value = Double(text)
        }
        else {
            buffer = buffers[text]
        }
    }
}
