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
        let outBuffer = outputs.first!.buffer!
        
        let array = inputs.first!.buffer!.toArray()
        
        //Only use accelerate for long arrays
        if array.count > 260 {
            var subtract = array
            subtract.insert(0.0, atIndex: 0)
            
            var out = array
            
            //array - subtract
            vDSP_vsubD(subtract, 1, array, 1, &out, 1, vDSP_Length(array.count))
            
            out.removeFirst()
            
            outBuffer.replaceValues(out)
        }
        else {
            var out: [Double] = []
            var first = true
            var last: Double!
            
            for value in inputs.first!.buffer! {
                if first {
                    last = value
                    first = false
                    continue
                }
                
                let val = value-last
                
                out.append(val)
                
                last = value
            }
            
            outBuffer.replaceValues(out)
        }
    }
}
