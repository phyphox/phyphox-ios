//
//  RampGeneratorAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation
import Accelerate

final class RampGeneratorAnalysis: ExperimentAnalysisModule {
    fileprivate var startInput: ExperimentAnalysisDataIO!
    fileprivate var stopInput: ExperimentAnalysisDataIO!
    fileprivate var lengthInput: ExperimentAnalysisDataIO?
    
    override init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String : AnyObject]?) throws {
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
        var start = 0.0
        var stop = 0.0
        var length = 0
        
        if let s = startInput.getSingleValue() {
            start = s
        }
        
        if let s = stopInput.getSingleValue() {
            stop = s
        }
        
        if let l = lengthInput?.getSingleValue() {
            length = Int(l)
        }

        if length == 0 {
            length = outputs.first!.buffer!.size
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
            if output.clear {
                output.buffer!.replaceValues(result)
            }
            else {
                output.buffer!.appendFromArray(result)
            }
        }
    }
}
