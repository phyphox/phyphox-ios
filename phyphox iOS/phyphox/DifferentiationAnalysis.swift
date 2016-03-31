//
//  DifferentiationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import Accelerate

final class DifferentiationAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        let array = inputs.first!.buffer!.toArray()
        
        var result: [Double]
        
        //Only use accelerate for long arrays
        if array.count > 260 {
            var subtract = array
            subtract.insert(0.0, atIndex: 0)
            
            result = array
            
            vDSP_vsubD(subtract, 1, array, 1, &result, 1, vDSP_Length(array.count))
            
            result.removeFirst()
        }
        else {
            result = []
            var first = true
            var last: Double!
            
            for value in inputs.first!.buffer! {
                if first {
                    last = value
                    first = false
                    continue
                }
                
                let val = value-last
                
                result.append(val)
                
                last = value
            }
        }
        
        for output in outputs {
            if output.clear {
                output.buffer!.replaceValues(result)
            }
            else {
                output.buffer!.appendFromArray(result)
            }
        }
    }
}
