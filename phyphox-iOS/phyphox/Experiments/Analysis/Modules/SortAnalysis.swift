//
//  SortAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 22.05.20.
//  Copyright © 2020 RWTH Aachen. All rights reserved.
//

import Foundation

final class SortAnalysis: AutoClearingExperimentAnalysisModule {
    
    private var ins: [ExperimentAnalysisDataInput] = []
    let descending: Bool;
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        
        let attributes = additionalAttributes.attributes(keyedBy: String.self)

        descending = try attributes.optionalValue(for: "descending") ?? false
        
        for input in inputs {
            if !input.isBuffer {
                throw SerializationError.genericError(message: "Error: Inputs of the sort module must be buffers.")
            }
            ins.append(input)
        }
        
        if (ins.count < 1) {
            throw SerializationError.genericError(message: "Error: No valid input for sort-module specified.")
        }
        
        if (outputs.count < 1) {
            throw SerializationError.genericError(message: "Error: No output for sort-module specified.")
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        let mainArray: [Double]
        switch ins[0] {
        case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
            mainArray = data.data
        case .value(value: _, usedAs: _):
            return
        }
        
        let offsets: [Int]
        if descending {
            offsets = mainArray.enumerated().sorted {$0.element > $1.element}.map{$0.offset}
        } else {
            offsets = mainArray.enumerated().sorted {$0.element < $1.element}.map{$0.offset}
        }
        
        var results: [[Double]] = []
        for (i, bufferIn) in ins.enumerated() {
            guard i < outputs.count else { break }

            switch bufferIn {
            case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                let inArray = data.data
                results.append(offsets.map{$0 < inArray.count ? inArray[$0] : Double.nan})
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
