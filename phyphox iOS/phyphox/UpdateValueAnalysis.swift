//
//  UpdateValueAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 21.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

/**
An abstract analysis module that takes one input and one output, writing each value of the input into the output (and clearing the output beforehand), after allowing a closure to update the value.
*/
class UpdateValueAnalysis: ExperimentAnalysisModule {
    
    internal func updateAllWithMethod(method: ([Double]) -> [Double]) {
        let input = inputs.first!
        
        let outBuffer = outputs.first!.buffer!
        
        var process: [Double] = []
        
        if let buffer = input.buffer {
            process.appendContentsOf(buffer)
        }
        else {
            process.append(input.value!)
        }
        
        #if DEBUG_ANALYSIS
            debug_noteInputs(process.description)
        #endif
        
        let append = method(process)
        
        #if DEBUG_ANALYSIS
            debug_noteOutputs(append)
        #endif
        
        outBuffer.replaceValues(append)
    }
    
}
