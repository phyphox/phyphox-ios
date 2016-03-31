//
//  IntegrationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation
import Accelerate

final class IntegrationAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        let buffer = inputs.first!.buffer
        
        if buffer == nil {
            return
        }
        
        var inArray = buffer!.toArray()
        let count = inArray.count
        
        var result = [Double](count: count, repeatedValue: 0.0)
        
        var factor = 1.0
        vDSP_vrsumD(inArray, 1, &factor, &result, 1, vDSP_Length(count+1))
        
        var repeatedVal = inArray[0]
        
        if repeatedVal != 0.0 {
            vDSP_vsaddD(result, 1, &repeatedVal, &result, 1, vDSP_Length(count))
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
