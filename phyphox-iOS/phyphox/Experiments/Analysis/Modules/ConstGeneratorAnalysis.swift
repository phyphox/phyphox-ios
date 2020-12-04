//
//  ConstGeneratorAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

final class ConstGeneratorAnalysis: ExperimentAnalysisModule {
    private var lengthInput: ExperimentAnalysisDataIO?
    private var valueInput: ExperimentAnalysisDataIO?
    
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: AttributeContainer) throws {
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
                case .buffer(buffer: let buffer, usedAs: _, clear: _):
                    length = buffer.size
                case .value(value: _, usedAs: _):
                    break
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
        
        beforeWrite()
        
        for output in outputs {
            switch output {
            case .value(value: _, usedAs: _):
                break
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(result)
                }
                else {
                    buffer.appendFromArray(result)
                }
            }
        }
    }
}
