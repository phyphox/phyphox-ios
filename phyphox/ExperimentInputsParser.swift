//
//  ExperimentInputsParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import UIKit

final class ExperimentInputsParser: ExperimentMetadataParser {
    typealias Output = NSArray?
    
    required init(_ inputs: NSDictionary) {
        var sensors = getElementsWithKey(inputs, key: "sensor")
        var audio = getElementsWithKey(inputs, key: "audio")
        
    }
    
    func parse() -> Output {
        return nil
    }
}
