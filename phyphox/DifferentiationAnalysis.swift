//
//  DifferentiationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class DifferentiationAnalysis: ExperimentAnalysis {
    
    override func update() {
        let out = outputs.first!.buffer!
        
        out.clear()
        
        var first = true
        var last: Double!
        
        for value in inputs.first!.buffer! {
            if first {
                last = value
                first = false
                continue
            }
            
            out.append(value-last)
            last = value
        }
    }
}
