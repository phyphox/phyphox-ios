//
//  AppendAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

final class AppendAnalysis: ExperimentAnalysisModule {
    private let inputElements: [ExperimentAnalysisDataIO]
    
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: AttributeContainer) throws {
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
            switch input {
            case .buffer(buffer: let buffer, usedAs: _, clear: _):
                result.append(contentsOf: buffer.toArray())
            case .value(value: let value, usedAs: _):
                result.append(value)
            }
        }
        
        #if DEBUG_ANALYSIS
            debug_noteOutputs(result)
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
