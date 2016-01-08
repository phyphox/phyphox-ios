//
//  ExperimentAnalysisParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentAnalysisParser: ExperimentMetadataParser {
    typealias Output = NSArray?
    
    let analyses: [String: [NSDictionary]]?
    var attributes: [String: String]?
    
    required init(_ data: NSDictionary) {
        var a: [String: [NSDictionary]] = [:]
        
        for (key, value) in data as! [String: AnyObject] {
            if key == XMLDictionaryAttributesKey {
                attributes = (value as! [String: String])
            }
            else {
                a[key] = (getElemetArrayFromValue(value) as! [NSDictionary])
            }
            
        }
        
        if a.count > 0 {
            analyses = a
        }
        else {
            analyses = nil
        }
    }
    
    private final class ExperimentAnalysisDataFlow {
        var asString: String?
        
        var bufferName: String?
        var value: Double?
        
        init(bufferName: String) {
            self.bufferName = bufferName
        }
        
        init(dictionary: NSDictionary) {
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
            }
            
            let text = dictionary[XMLDictionaryTextKey] as! String
            
            if typeIsValue {
                value = Double(text)
            }
            else {
                bufferName = text
            }
        }
    }
    
    func parse() -> Output {
        if analyses == nil {
            return nil
        }
        
        let sleep = doubleFromXML(attributes, key: "sleep", defaultValue: 0.0)
        let onUserInput = boolFromXML(attributes, key: "onUserInout", defaultValue: false)
        
        func getDataFlows(dictionaries: [AnyObject]) -> [ExperimentAnalysisDataFlow] {
            let c = dictionaries.count
            var a = [ExperimentAnalysisDataFlow!](count: c, repeatedValue: nil)
            
            for (i, object) in dictionaries.enumerate() {
                if object.isKindOfClass(NSDictionary) {
                    a[i] = ExperimentAnalysisDataFlow(dictionary: object as! NSDictionary)
                }
                else {
                    a[i] = ExperimentAnalysisDataFlow(bufferName: object as! String)
                }
            }
            
            return a as! [ExperimentAnalysisDataFlow]
        }
        
        for (key, values) in analyses! {
            for value in values {
                let inputs = getDataFlows(getElementsWithKey(value, key: "input")!)
                let outputs = getDataFlows(getElementsWithKey(value, key: "output")!)
                
                if key == "add" {
                    
                }
                else if key == "subtract" {
                    
                }
                else if key == "multiply" {
                    
                }
                else if key == "divide" {
                    
                }
                else if key == "power" {
                    
                }
                else if key == "gcd" {
                    
                }
                else if key == "lcm" {
                    
                }
                else if key == "abs" {
                    
                }
                else if key == "sin" {
                    
                }
                else if key == "cos" {
                    
                }
                else if key == "tan" {
                    
                }
                else if key == "first" {
                    
                }
                else if key == "max" {
                    
                }
                else if key == "threshold" {
                    
                }
                else if key == "append" {
                    
                }
                else if key == "fft" {
                    
                }
                else if key == "autocorrelation" {
                    
                }
                else if key == "differentiate" {
                    
                }
                else if key == "integrate" {
                    
                }
                else if key == "crosscorrelation" {
                    
                }
                else if key == "gausssmooth" {
                    
                }
                else if key == "rangefilter" {
                    
                }
                else if key == "ramp" {
                    
                }
                else if key == "const" {
                    
                }
                else {
                    print("Error! Invalid analysis type: \(key)")
                }
            }
        }
        
        return nil
    }
}
