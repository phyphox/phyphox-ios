//
//  ConstGeneratorAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//


import Foundation

final class ConstGeneratorAnalysis: ExperimentAnalysisModule {
    private var lengthInput: ExperimentAnalysisDataIO!
    private var valueInput: ExperimentAnalysisDataIO!
    
    override init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String : AnyObject]?) {
        for input in inputs {
            if input.asString == "value" {
                valueInput = input
            }
            else if input.asString == "length" {
                lengthInput = input
            }
            else {
                print("Error: Invalid analysis input: \(input.asString)")
            }
        }
        
        super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        var value: Double = 0
        var length: Int = 0
        
        if let v = valueInput.getSingleValue() {
            value = v
        }
        
        if let l = lengthInput.getSingleValue() {
            length = Int(l)
        }
        
        if length == 0 {
            length = outputs.first!.buffer!.size
        }
        
        #if DEBUG_ANALYSIS
            debug_noteInputs(["value" : value, "length" : length])
        #endif
        
        let result = [Double](count: length, repeatedValue: value)
        
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
