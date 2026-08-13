//
//  SubrangeAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 12.02.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//


import Foundation

final class SubrangeAnalysis: AutoClearingExperimentAnalysisModule {
    private static let fromInSlot = AnalysisIOSlot(name: "from", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let toInSlot = AnalysisIOSlot(name: "to", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let lengthInSlot = AnalysisIOSlot(name: "length", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let dataInSlot = AnalysisIOSlot(name: "in", asRequired: false, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 0)
    private static let outOutSlot = AnalysisIOSlot(name: "out", asRequired: false, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 0)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.fromInSlot, Self.toInSlot, Self.lengthInSlot, Self.dataInSlot], outputs: [Self.outOutSlot])
    }
    
    private var from: ExperimentAnalysisDataInput? = nil
    private var to: ExperimentAnalysisDataInput? = nil
    private var length: ExperimentAnalysisDataInput? = nil
    private var arrayIns: [ExperimentAnalysisDataInput] = []
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        
        let io = try Self.mapIO(inputs: inputs, outputs: outputs)
        from = io.input(Self.fromInSlot)
        to = io.input(Self.toInSlot)
        length = io.input(Self.lengthInSlot)
        arrayIns = io.inputs(Self.dataInSlot)

        if (outputs.count < 1) {
            throw SerializationError.genericError(message: "Error: No output for subrange-module specified.")
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        var start = 0
        var end = -1
        
        if let v = from?.getSingleValueAsInt() {
            start = v
        }
        
        if let v = to?.getSingleValueAsInt() {
            end = v
        }
        
        if let v = length?.getSingleValueAsInt() {
            end = start + v
        }
        
        if start < 0 {
            start = 0
        }
        
        if end < 0 {
            for arrayIn in arrayIns {
                switch arrayIn {
                case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                    end = max(end, data.data.count)
                case .value(value: _, usedAs: _):
                    break
                }
            }
        }
        
        var results: [[Double]] = []
        for (i, arrayIn) in arrayIns.enumerated() {
            guard i < outputs.count else { break }
            
            switch arrayIn {
            case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                let data = data.data
                let thisEnd = min(end, data.count)
                if thisEnd < start {
                    results.append([])
                } else {
                    results.append(Array(data[start..<thisEnd]))
                }
                
            case .value(value: _, usedAs: _):
                results.append([])
            }
            
        }
                     
        for (i, result) in results.enumerated() {

            let output = outputs[i]

            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(result)
            }
        }
    }
}
