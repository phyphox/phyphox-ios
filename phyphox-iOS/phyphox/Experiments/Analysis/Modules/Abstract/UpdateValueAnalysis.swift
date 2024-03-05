//
//  UpdateValueAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 21.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

/**
An abstract analysis module that takes one input and one output, writing each value of the input into the output (and clearing the output beforehand), after allowing a closure to update the value.
*/
class UpdateValueAnalysis: AutoClearingExperimentAnalysisModule {
    func updateAllWithMethod(_ method: ([Double]) -> [Double]) {
        guard let input = inputs.first else { return }
        
        let process: [Double]

        switch input {
        case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
            process = data.data
        case .value(value: let value, usedAs: _):
            process = [value]
        }
        
        #if DEBUG_ANALYSIS
            debug_noteInputs(process.description)
        #endif
        
        let result = method(process)
        
        #if DEBUG_ANALYSIS
//            debug_noteOutputs(append)
        #endif
                
        for output in outputs {
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(result)
            }
        }
    }
}
