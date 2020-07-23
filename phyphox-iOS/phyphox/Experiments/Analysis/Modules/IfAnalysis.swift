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
    
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: AttributeContainer) throws {
        let attributes = additionalAttributes.attributes(keyedBy: String.self)

        less = try attributes.optionalValue(for: "less") ?? false
        equal = try attributes.optionalValue(for: "equal") ?? false
        greater = try attributes.optionalValue(for: "greater") ?? false

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
                throw SerializationError.genericError(message: "Error: Invalid analysis input: \(String(describing: input.asString))")
            }
        }
        
        if (in1 == nil) {
            throw SerializationError.genericError(message: "Error: Missing input for in1.")
        }
        if (in2 == nil) {
            throw SerializationError.genericError(message: "Error: Missing input for in2.")
        }
        
        if (outputs.count < 1) {
            throw SerializationError.genericError(message: "Error: No output for if-module specified.")
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        guard let firstOutput = outputs.first else { return }

        let v1 = in1!.getSingleValue()
        let v2 = in2!.getSingleValue()

        if v1 == nil || v2 == nil {
            return
        }
        
        let out: ExperimentAnalysisDataIO?
        
        if (v1! < v2! && less) || (v1! == v2! && equal) || (v1! > v2! && greater) {
            out = inTrue
        } else {
            out = inFalse
        }
        
        guard let output = out else { return }

        let outputValues: [Double]

        switch output {
        case .buffer(buffer: let buffer, usedAs: _, clear: _):
            outputValues = buffer.toArray()
        case .value(value: let value, usedAs: _):
            outputValues = [value]
        }

        beforeWrite()

        switch firstOutput {
        case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
            if clear {
                buffer.replaceValues(outputValues)
            }
            else {
                buffer.appendFromArray(outputValues)
            }
        case .value(value: _, usedAs: _):
            break
        }
    }
}
