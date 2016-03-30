//
//  AppendAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class AppendAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        let outBuffer = outputs.first!.buffer!
        
        var append: [Double] = []
        
        #if DEBUG_ANALYSIS
            debug_noteInputs(inputs)
        #endif
        
        for input in inputs {
            if let b = input.buffer {
                append.appendContentsOf(b)
            }
        }
        
        #if DEBUG_ANALYSIS
            debug_noteOutputs(append)
        #endif
        
        outBuffer.appendFromArray(append)
    }
}
