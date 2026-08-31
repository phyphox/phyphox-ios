//
//  ExperimentComplexUpdateValueAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 31.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

// TODO: Should be an enum
final class ValueSource: CustomStringConvertible {
    var vector: [Double]? {
        didSet {
            if vector?.count == 1, let first = vector?.first {
                scalar = first
                vector = nil
            }
        }
    }
    
    var scalar: Double?
    
    init(scalar: Double) {
        self.scalar = scalar
    }
    
    init(vector: [Double]) {
        self.vector = vector
    }
    
    var description: String {
        if vector != nil {
            return "Vector: \(vector!)"
        }
        else {
            return "Scalar: \(scalar!)"
        }
    }
}

class ExperimentComplexUpdateValueAnalysis: AutoClearingExperimentAnalysisModule {
    func updateAllWithMethod(_ method: ([ValueSource]) -> ValueSource) {
        //Operands follow the validated slot mapping: as attributes are matched
        //case-insensitively and unnamed inputs fill the remaining slots in declaration order,
        //matching Android's ioBlockParser. Consuming document order with an exact-match
        //priority key used to silently swap operands for files that name only the second
        //operand or write the first slot's name with different case.
        let orderedInputs: [ExperimentAnalysisDataInput]
        if let mapping = type(of: self).ioMapping, let mapped = try? type(of: self).mapIO(inputs: inputs, outputs: outputs) {
            orderedInputs = mapping.inputs.flatMap { mapped.inputs($0) }
        } else {
            orderedInputs = inputs
        }

        var values: [ValueSource] = []
        var maxCount = 0
        var emptyVector = false //Scalar and an empty vector should give an empty result

        for input in orderedInputs {
            switch input {
            case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                let array = data.data

                values.append(ValueSource(vector: array))

                if (array.count == 0) {
                    emptyVector = true
                }
                maxCount = Swift.max(maxCount, array.count)

                if array.count == 0 {
                    maxCount = 0
                    break
                }
            case .value(value: let fixed, usedAs: _):
                values.append(ValueSource(scalar: fixed))

                maxCount = Swift.max(maxCount, 1)
            }
        }
        
        let result: [Double]
        
        if values.count == 0 || maxCount == 0 || emptyVector {
            result = []
        }
        else {
            for valueSource in values {
                if var array = valueSource.vector {
                    let delta = maxCount-array.count
                    
                    if delta > 0 {
                        array.append(contentsOf: [Double](repeating: array.last ?? Double.nan, count: delta))
                        valueSource.vector = array
                    }
                }
            }
            
            #if DEBUG_ANALYSIS
                debug_noteInputs(values.description)
            #endif
            
            let out = method(values)
            
            #if DEBUG_ANALYSIS
                debug_noteOutputs(out)
            #endif
            
            result = (out.scalar != nil ? [out.scalar!] : out.vector!)
        }
                
        for output in outputs {
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(result)
            }
        }
    }
}
