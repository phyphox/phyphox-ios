//
//  RampGeneratorAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

final class RampGeneratorAnalysis: AutoClearingExperimentAnalysisModule {
    private var startInput: ExperimentAnalysisDataInput!
    private var stopInput: ExperimentAnalysisDataInput!
    private var lengthInput: ExperimentAnalysisDataInput?
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
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
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                length = buffer.size
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
                
        for output in outputs {
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(result)
            }
        }
    }
}
