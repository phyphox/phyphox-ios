//
//  SortAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 22.05.20.
//  Copyright © 2020 RWTH Aachen. All rights reserved.
//

import Foundation

final class SortAnalysis: AutoClearingExperimentAnalysisModule {
    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [
            AnalysisIOSlot(name: "in", asRequired: false, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 0)
        ], outputs: [
            AnalysisIOSlot(name: "out", asRequired: false, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 0)
        ])
    }
    
    private var ins: [ExperimentAnalysisDataInput] = []
    var descending: Bool //var and internal for the unit tests, which cannot construct attributes
    
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
        
        //All buffers are truncated to the shortest input before sorting (matching Android) -
        //no NaN substitution for shorter co-buffers
        var count = mainArray.count
        for input in ins {
            switch input {
            case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                count = Swift.min(count, data.data.count)
            case .value(value: _, usedAs: _):
                break
            }
        }

        //NaN sorts deterministically as the largest value, like Java's Double.compareTo on
        //Android. The plain </> closures violate strict weak ordering when NaN is present,
        //leaving the NaN placement unspecified.
        func sortsBefore(_ a: Double, _ b: Double) -> Bool {
            if a.isNaN {
                return false
            }
            if b.isNaN {
                return true
            }
            return a < b
        }

        let offsets: [Int]
        if descending {
            offsets = mainArray[0..<count].enumerated().sorted {sortsBefore($1.element, $0.element)}.map{$0.offset}
        } else {
            offsets = mainArray[0..<count].enumerated().sorted {sortsBefore($0.element, $1.element)}.map{$0.offset}
        }

        var results: [[Double]] = []
        for (i, bufferIn) in ins.enumerated() {
            guard i < outputs.count else { break }

            switch bufferIn {
            case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                let inArray = data.data
                results.append(offsets.map{inArray[$0]})
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
