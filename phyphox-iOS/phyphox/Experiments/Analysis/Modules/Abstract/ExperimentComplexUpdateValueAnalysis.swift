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
    func updateAllWithMethod(_ method: ([ValueSource]) -> ValueSource, priorityInputKey: String?) {
        var values: [ValueSource] = []
        var maxCount = 0
        var emptyVector = false //Scalar and an empty vector should give an empty result
        
        for input in inputs {
            switch input {
            case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                let array = data.data

                let src = ValueSource(vector: array)

                if priorityInputKey != nil && input.asString == priorityInputKey! {
                    values.insert(src, at: 0)
                }
                else {
                    values.append(src)
                }

                if (array.count == 0) {
                    emptyVector = true
                }
                maxCount = Swift.max(maxCount, array.count)
                
                if array.count == 0 {
                    maxCount = 0
                    break
                }
            case .value(value: let fixed, usedAs: _):
                let src = ValueSource(scalar: fixed)

                if priorityInputKey != nil && input.asString == priorityInputKey! {
                    values.insert(src, at: 0)
                }
                else {
                    values.append(src)
                }

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
