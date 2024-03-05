//
//  AppendAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

final class AppendAnalysis: AutoClearingExperimentAnalysisModule {
    private let inputElements: [ExperimentAnalysisDataInput]
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        
        var inputElements = [ExperimentAnalysisDataInput]()
        
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
            case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                result.append(contentsOf: data.data)
            case .value(value: let value, usedAs: _):
                result.append(value)
            }
        }
        
        #if DEBUG_ANALYSIS
            debug_noteOutputs(result)
        #endif
                
        for output in outputs {
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(result)
            }
        }
    }
}
