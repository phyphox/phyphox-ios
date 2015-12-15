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
    
    func parse() -> Output {
        if analyses == nil {
            return nil
        }
        
        let sleep = doubleFromXML(attributes, key: "sleep", defaultValue: 0.0)
        let onUserInput = boolFromXML(attributes, key: "onUserInout", defaultValue: false)
        
        for (key, value) in analyses! {

        }
        
        return nil
    }
}
