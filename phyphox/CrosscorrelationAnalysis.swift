//
//  CrosscorrelationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import Accelerate

final class CrosscorrelationAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        var a: [Double]
        var b: [Double]
        
        let firstBuffer = inputs.first!.buffer!
        let secondBuffer = inputs[1].buffer!
        
        //Put the larger input in a and the smaller one in b
        if (firstBuffer.count > secondBuffer.count) {
            a = firstBuffer.toArray()
            b = secondBuffer.toArray()
        }
        else {
            b = firstBuffer.toArray()
            a = secondBuffer.toArray()
        }
        
        let compRange = a.count-b.count
        
        #if DEBUG_ANALYSIS
            debug_noteInputs(["a" : a, "b" : b])
        #endif
        
        var result = [Double](count: compRange, repeatedValue: 0.0)
        
        vDSP_convD(a, 1, b, 1, &result, 1, vDSP_Length(compRange), vDSP_Length(b.count))

        #if DEBUG_ANALYSIS
            debug_noteOutputs(result)
        #endif
        
        let outBuffer = outputs.first!.buffer!
        outBuffer.replaceValues(result)
    }
}
