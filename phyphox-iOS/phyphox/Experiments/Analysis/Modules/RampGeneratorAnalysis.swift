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
    private static let startInSlot = AnalysisIOSlot(name: "start", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let stopInSlot = AnalysisIOSlot(name: "stop", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let lengthInSlot = AnalysisIOSlot(name: "length", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let outOutSlot = AnalysisIOSlot(name: "out", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.startInSlot, Self.stopInSlot, Self.lengthInSlot], outputs: [Self.outOutSlot])
    }
    private var startInput: ExperimentAnalysisDataInput!
    private var stopInput: ExperimentAnalysisDataInput!
    private var lengthInput: ExperimentAnalysisDataInput?
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        let io = try Self.mapIO(inputs: inputs, outputs: outputs)
        startInput = io.input(Self.startInSlot)
        stopInput = io.input(Self.stopInSlot)
        lengthInput = io.input(Self.lengthInSlot)
        
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
