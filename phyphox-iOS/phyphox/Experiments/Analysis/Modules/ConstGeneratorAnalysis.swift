//
//  ConstGeneratorAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

final class ConstGeneratorAnalysis: AutoClearingExperimentAnalysisModule {
    private var lengthInput: ExperimentAnalysisDataInput?
    private var valueInput: ExperimentAnalysisDataInput?
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        for input in inputs {
            if input.asString == "value" {
                valueInput = input
            }
            else if input.asString == "length" {
                lengthInput = input
            }
            else {
                print("Error: Invalid analysis input: \(String(describing: input.asString))")
            }
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        var value: Double = 0
        var length: Int = 0
        
        if let v = valueInput?.getSingleValue() {
            value = v
        }
        
        if let l = lengthInput?.getSingleValue() {
            length = Int(l)
        }
        
        if length == 0 {
            outputs.first.map {
                switch $0 {
                case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                    length = buffer.size
                }
            }
        }
        
        #if DEBUG_ANALYSIS
            debug_noteInputs(["value" : value, "length" : length])
        #endif
        
        let result = [Double](repeating: value, count: length)
        
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
