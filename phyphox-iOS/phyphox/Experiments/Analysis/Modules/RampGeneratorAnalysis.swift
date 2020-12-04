//
//  RampGeneratorAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

final class RampGeneratorAnalysis: ExperimentAnalysisModule {
    private var startInput: ExperimentAnalysisDataIO!
    private var stopInput: ExperimentAnalysisDataIO!
    private var lengthInput: ExperimentAnalysisDataIO?
    
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: AttributeContainer) throws {
        for input in inputs {
            if input.asString == "start" {
                startInput = input
            }
            else if input.asString == "stop" {
                stopInput = input
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
        guard let firstOutput = outputs.first else { return }

        var start = 0.0
        var stop = 0.0
        var length = 0
        
        if let s = startInput.getSingleValue() {
            start = s
        }
        
        if let s = stopInput.getSingleValue() {
            stop = s
        }
        
        if let l = lengthInput?.getSingleValueAsInt() {
            length = l
        }

        if length == 0 {
            switch firstOutput {
            case .buffer(buffer: let buffer, usedAs: _, clear: _):
                length = buffer.size
            case .value(value: _, usedAs: _):
                break
            }
        }
        
        var result = [Double](repeating: 0.0, count: length)
        
        #if DEBUG_ANALYSIS
            debug_noteInputs(["start" : start, "stop" : stop, "length" : length])
        #endif
        
        var step = (stop-start)/Double(length-1)
        
        vDSP_vrampD(&start, &step, &result, 1, vDSP_Length(length))
        
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
