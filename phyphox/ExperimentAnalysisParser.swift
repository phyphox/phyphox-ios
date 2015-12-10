//
//  ExperimentAnalysisParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import UIKit

final class ExperimentAnalysisParser: ExperimentMetadataParser {
    typealias Output = NSArray?
    
    let analyses: [NSDictionary]?
    
    required init(_ data: NSDictionary) {
        var a: [NSDictionary] = []
        
        for (_, value) in data {
            a.appendContentsOf(getElemetArrayFromValue(value) as! [NSDictionary])
        }
        
        if a.count > 0 {
            analyses = a
        }
        else {
            analyses = nil
        }
    }
    
    func parse() -> Output {
        return nil
    }
}
