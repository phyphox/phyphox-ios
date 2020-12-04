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
class UpdateValueAnalysis: ExperimentAnalysisModule {
    func updateAllWithMethod(_ method: ([Double]) -> [Double]) {
        guard let input = inputs.first else { return }
        
        let process: [Double]

        switch input {
        case .buffer(buffer: let buffer, usedAs: _, clear: _):
            process = buffer.toArray()
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
        
        beforeWrite()
        
        for output in outputs {
            switch output {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(result)
                }
                else {
                    buffer.appendFromArray(result)
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
    }
}
