//
//  SubrangeAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 12.02.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//


import Foundation

final class SubrangeAnalysis: AutoClearingExperimentAnalysisModule {
    
    private var from: ExperimentAnalysisDataInput? = nil
    private var to: ExperimentAnalysisDataInput? = nil
    private var length: ExperimentAnalysisDataInput? = nil
    private var arrayIns: [ExperimentAnalysisDataInput] = []
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        
        for input in inputs {
            if input.asString == "from" {
                from = input
            }
            else if input.asString == "to" {
                to = input
            }
            else if input.asString == "length" {
                length = input
            }
            else {
                if !input.isBuffer {
                    throw SerializationError.genericError(message: "Error: Regular inputs of the subrange module besides from, to or length must be buffers.")
                }
                arrayIns.append(input)
            }
        }
        
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
