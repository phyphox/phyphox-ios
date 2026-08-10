//
//  IfAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 12.11.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation


final class IfAnalysis: ExperimentAnalysisModule {
    private static let aInSlot = AnalysisIOSlot(name: "a", asRequired: false, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let bInSlot = AnalysisIOSlot(name: "b", asRequired: false, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let trueInSlot = AnalysisIOSlot(name: "true", asRequired: false, repeatOffset: -1, valueAllowed: true, emptyAllowed: true, minCount: 0, maxCount: 1)
    private static let falseInSlot = AnalysisIOSlot(name: "false", asRequired: false, repeatOffset: -1, valueAllowed: true, emptyAllowed: true, minCount: 0, maxCount: 1)
    private static let resultOutSlot = AnalysisIOSlot(name: "result", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.aInSlot, Self.bInSlot, Self.trueInSlot, Self.falseInSlot], outputs: [Self.resultOutSlot])
    }
    private let less: Bool
    private let equal: Bool
    private let greater: Bool
    
    private var in1: ExperimentAnalysisDataInput? = nil
    private var in2: ExperimentAnalysisDataInput? = nil
    private var inTrue: ExperimentAnalysisDataInput? = nil
    private var inFalse: ExperimentAnalysisDataInput? = nil
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        let attributes = additionalAttributes.attributes(keyedBy: String.self)

        less = try attributes.optionalValue(for: "less") ?? false
        equal = try attributes.optionalValue(for: "equal") ?? false
        greater = try attributes.optionalValue(for: "greater") ?? false

        let io = try Self.mapIO(inputs: inputs, outputs: outputs)
        in1 = io.input(Self.aInSlot)
        in2 = io.input(Self.bInSlot)
        inTrue = io.input(Self.trueInSlot)
        inFalse = io.input(Self.falseInSlot)

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
        clearInputs()
        
        guard let firstOutput = outputs.first else { return }

        let v1 = in1!.getSingleValue()
        let v2 = in2!.getSingleValue()
        
        if v1 == nil || v2 == nil {
            return
        }
        
        let out: ExperimentAnalysisDataInput?
        
        if (v1! < v2! && less) || (v1! == v2! && equal) || (v1! > v2! && greater) {
            out = inTrue
        } else {
            out = inFalse
        }
                
        guard let output = out else { return }

        let outputValues: [Double]

        switch output {
        case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
            outputValues = data.data
        case .value(value: let value, usedAs: _):
            outputValues = [value]
        }

        switch firstOutput {
        case .buffer(buffer: let buffer, data: _, usedAs: _, append: let append):
            if !append {
                buffer.replaceValues(outputValues)
            }
            else {
                buffer.appendFromArray(outputValues)
            }
        }
    }
}
