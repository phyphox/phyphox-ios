//
//  IntegrationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation
import Accelerate

final class IntegrationAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        let buffer = inputs.first!.buffer!
        
        var inArray = buffer.toArray()
        let count = inArray.count
        
        var result: [Double]
        
        if count == 0 {
            result = []
        }
        else {
            result = [Double](repeating: 0.0, count: count)
            
            var factor = 1.0
            vDSP_vrsumD(inArray, 1, &factor, &result, 1, vDSP_Length(count))
            
            var repeatedVal = inArray[0]
            
            if repeatedVal != 0.0 {
                vDSP_vsaddD(result, 1, &repeatedVal, &result, 1, vDSP_Length(count))
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
