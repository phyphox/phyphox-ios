//
//  AppendAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

final class AppendAnalysis: ExperimentAnalysisModule {
    private let inputElements: [ExperimentAnalysisDataIO]
    
    override init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String : AnyObject]?) throws {
        var inputElements = [ExperimentAnalysisDataIO]()
        
        for input in inputs {
            inputElements.append(input)
        }
        
        self.inputElements = inputElements
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        var result: [Double] = []
        
        #if DEBUG_ANALYSIS
            debug_noteInputs(inputs)
        #endif
        for input in inputElements {
            if let b = input.buffer {
                result.appendContentsOf(b.toArray())
            } else {
                result.append(input.getSingleValue()!)
            }
        }
        
        #if DEBUG_ANALYSIS
            debug_noteOutputs(result)
        #endif
        
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
