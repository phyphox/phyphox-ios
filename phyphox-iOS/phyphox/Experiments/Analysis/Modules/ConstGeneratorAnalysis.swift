//
//  ConstGeneratorAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

final class ConstGeneratorAnalysis: AutoClearingExperimentAnalysisModule {
    private static let valueInSlot = AnalysisIOSlot(name: "value", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let lengthInSlot = AnalysisIOSlot(name: "length", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let outOutSlot = AnalysisIOSlot(name: "out", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.valueInSlot, Self.lengthInSlot], outputs: [Self.outOutSlot])
    }
    private var lengthInput: ExperimentAnalysisDataInput?
    private var valueInput: ExperimentAnalysisDataInput?
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        let io = try Self.mapIO(inputs: inputs, outputs: outputs)
        valueInput = io.input(Self.valueInSlot)
        lengthInput = io.input(Self.lengthInSlot)
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        //An absent value input keeps the default 0; a present input with an empty buffer is an
        //error yielding empty output. A present NaN value is permitted and fills the output
        //with NaN as a deliberate initialization.
        let value: Double
        if let valueInput = valueInput {
            guard let v = valueInput.getSingleValue() else {
                return
            }
            value = v
        } else {
            value = 0
        }

        //An explicit length of 0, an empty length buffer and a non-finite or negative length
        //all yield an empty output; only an absent length input falls back to the output
        //buffer's size.
        var length: Int = 0
        if let lengthInput = lengthInput {
            guard let l = lengthInput.getSingleValue(), l.isFinite, l >= 0, l < 9e18 else {
                return
            }
            length = Int(l)
        } else {
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
