//
//  SubrangeAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 12.02.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//


import Foundation

final class SubrangeAnalysis: ExperimentAnalysisModule {
    
    fileprivate var from: ExperimentAnalysisDataIO? = nil
    fileprivate var to: ExperimentAnalysisDataIO? = nil
    fileprivate var length: ExperimentAnalysisDataIO? = nil
    fileprivate var arrayIns: [ExperimentAnalysisDataIO] = []
    
    override init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String : AnyObject]?) throws {
        
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
                if (input.buffer == nil) {
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
        
        if let v = from?.getSingleValue() {
            start = Int(v)
        }
        
        if let v = to?.getSingleValue() {
            end = Int(v)
        }
        
        if let v = length?.getSingleValue() {
            end = start + Int(v)
        }
        
        if (start < 0 || start > end) {
            start = 0
        }
        
        if (end < 0) {
            for arrayIn in arrayIns {
                if end < arrayIn.buffer!.actualCount {
                    end = arrayIn.buffer!.actualCount
                }
            }
        }
        
        for (i, arrayIn) in arrayIns.enumerated() {
            if (outputs.count > i) && outputs[i].buffer != nil {
                let thisEnd = min(end, arrayIn.buffer!.actualCount)
                if (thisEnd < start) {
                    continue
                }
                let result = Array(arrayIn.buffer!.toArray()[start..<thisEnd])
                if outputs[i].clear {
                    outputs[i].buffer!.replaceValues(result)
                }
                else {
                    outputs[i].buffer!.appendFromArray(result)
                }
            }
        }
        
    }
}
