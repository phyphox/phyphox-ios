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
        
        var out = [Double](count: count, repeatedValue: 0.0)
        
        var factor = 1.0
        vDSP_vrsumD(inArray, 1, &factor, &out, 1, vDSP_Length(count+1))
        
        var repeatedVal = inArray[0]
        
        if repeatedVal != 0.0 {
            vDSP_vsaddD(out, 1, &repeatedVal, &out, 1, vDSP_Length(count))
        }
        
        let outBuffer = outputs.first!.buffer!
        
        outBuffer.replaceValues(out)
    }
}
