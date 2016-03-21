//
//  DifferentiationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class DifferentiationAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        let outBuffer = outputs.first!.buffer!
        
        var append: [Double] = []
        
        var first = true
        var last: Double!
        
        for value in inputs.first!.buffer! {
            if first {
                last = value
                first = false
                continue
            }
            
            let val = value-last
            
            append.append(val)
            
            last = value
        }
        
        outBuffer.replaceValues(append)
    }
}
