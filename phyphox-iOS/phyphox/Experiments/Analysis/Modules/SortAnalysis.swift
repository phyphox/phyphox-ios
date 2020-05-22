//
//  SortAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 22.05.20.
//  Copyright © 2020 RWTH Aachen. All rights reserved.
//

import Foundation

final class SortAnalysis: ExperimentAnalysisModule {
    
    private var ins: [ExperimentAnalysisDataIO] = []
    let descending: Bool;
    
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: AttributeContainer) throws {
        
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
        case .buffer(buffer: let buffer, usedAs: _, clear: _):
            mainArray = buffer.toArray()
        case .value(value: _, usedAs: _):
            return
        }
        
        let offsets: [Int]
        if descending {
            offsets = mainArray.enumerated().sorted {$0.element > $1.element}.map{$0.offset}
        } else {
            offsets = mainArray.enumerated().sorted {$0.element < $1.element}.map{$0.offset}
        }
        
        for (i, bufferIn) in ins.enumerated() {
            let inArray: [Double]

            switch bufferIn {
            case .buffer(buffer: let buffer, usedAs: _, clear: _):
                inArray = buffer.toArray()
            case .value(value: _, usedAs: _):
                continue
            }

            guard i < outputs.count else { break }

            let output = outputs[i]

            switch output {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(offsets.map{inArray[$0]})
                }
                else {
                    buffer.appendFromArray(offsets.map{inArray[$0]})
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
    }
}
