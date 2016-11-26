//
//  IfAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 12.11.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class IfAnalysis: ExperimentAnalysisModule {
    private let less: Bool
    private let equal: Bool
    private let greater: Bool
    
    private var in1: ExperimentAnalysisDataIO? = nil
    private var in2: ExperimentAnalysisDataIO? = nil
    private var inTrue: ExperimentAnalysisDataIO? = nil
    private var inFalse: ExperimentAnalysisDataIO? = nil
    
    override init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String : AnyObject]?) throws {
        less = boolFromXML(additionalAttributes, key: "less", defaultValue: false)
        equal = boolFromXML(additionalAttributes, key: "equal", defaultValue: false)
        greater = boolFromXML(additionalAttributes, key: "greater", defaultValue: false)
        
        for input in inputs {
            if input.asString == "a" {
                in1 = input
            }
            else if input.asString == "b" {
                in2 = input
            }
            else if input.asString == "true" {
                inTrue = input
            }
            else if input.asString == "false" {
                inFalse = input
            }
            else {
                if (in1 == nil) {
                    in1 = input
                    continue
                }
                if (in2 == nil) {
                    in2 = input
                    continue
                }
                if (inTrue == nil) {
                    inTrue = input
                    continue
                }
                if (inFalse == nil) {
                    inFalse = input
                    continue
                }
                throw SerializationError.GenericError(message: "Error: Invalid analysis input: \(input.asString)")
            }
            if (in1 == nil) {
                throw SerializationError.GenericError(message: "Error: Missing input for in1.")
            }
            if (in2 == nil) {
                throw SerializationError.GenericError(message: "Error: Missing input for in2.")
            }
            if (inTrue == nil) {
                throw SerializationError.GenericError(message: "Error: Missing input for inTrue.")
            }
            if (inFalse == nil) {
                throw SerializationError.GenericError(message: "Error: Missing input for inFalse.")
            }
            
            if (outputs.count < 1) {
                throw SerializationError.GenericError(message: "Error: No output for if-module specified.")
            }
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        let v1 = in1!.getSingleValue()
        let v2 = in2!.getSingleValue()

        if v1 == nil || v2 == nil {
            return
        }
        
        let out: ExperimentAnalysisDataIO!
        
        if (v1 < v2 && less) || (v1 == v2 && equal) || (v1 > v2 && greater) {
            out = inTrue!
        } else {
            out = inFalse!
        }
        
        if outputs[0].clear {
            if (out.value != nil) {
                outputs[0].buffer!.replaceValues([out.value!])
            } else {
                outputs[0].buffer!.replaceValues(out.buffer!.toArray())
            }
        }
        else {
            if (out.value != nil) {
                outputs[0].buffer!.append(out.value!)
            } else {
                outputs[0].buffer!.appendFromArray(out.buffer!.toArray())
            }
        }
    }
}
