//
//  ConstGeneratorAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class ConstGeneratorAnalysis: ExperimentAnalysis {
    private var value = "0"
    private var length = "-1"
    
    func setParameters(value: String?, length: String?) {
        if value != nil {
            self.value = value!
        }
        if length != nil {
            self.length = length!
        }
    }
    
    override func update() {
        let vValue = getSingleValueFromUserString(value)
        var vLength = Int(getSingleValueFromUserString(length)!)
        
        outputs.first!.clear()
        
        if vLength < 0 {
            vLength = outputs.first!.size
        }
        
        for _ in 0..<vLength {
            outputs.first!.append(vValue)
        }
    }
}
