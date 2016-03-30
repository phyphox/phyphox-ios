//
//  ExperimentComplexUpdateValueAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 31.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

internal final class ValueSource : CustomStringConvertible {
    var vector: [Double]?
    var scalar: Double?
    
    init(scalar: Double) {
        self.scalar = scalar
    }
    
    init(vector: [Double]) {
        self.vector = vector
    }
    
    var description: String {
        get {
            if vector != nil {
                return "Vector: \(vector!)"
            }
            else {
                return "Scalar: \(scalar!)"
            }
        }
    }
}

class ExperimentComplexUpdateValueAnalysis: ExperimentAnalysisModule {
    
    func updateAllWithMethod(method: [ValueSource] -> ValueSource, priorityInputKey: String?) {
        var values: [ValueSource] = []
        var maxCount = 0
        
        for input in inputs {
            if let fixed = input.value {
                let src = ValueSource(scalar: fixed)
                
                if priorityInputKey != nil && input.asString == priorityInputKey! {
                    values.insert(src, atIndex: 0)
                }
                else {
                    values.append(src)
                }
                
                maxCount = Swift.max(maxCount, 1)
            }
            else {
                let array = input.buffer!.toArray()
                
                let src = array.count == 1 ? ValueSource(scalar: array[0]) : ValueSource(vector: array)
                
                if priorityInputKey != nil && input.asString == priorityInputKey! {
                    values.insert(src, atIndex: 0)
                }
                else {
                    values.append(src)
                }
                
                maxCount = Swift.max(maxCount, array.count)
            }
        }
        
        if values.count == 0 || maxCount == 0 {
            return
        }
        
        for valueSource in values {
            if var array = valueSource.vector {
                let delta = maxCount-array.count
                
                if delta > 0 {
                    array.appendContentsOf([Double](count: delta, repeatedValue: array.last ?? 0.0))
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
        
        let outValue = (out.scalar != nil ? [out.scalar!] : out.vector!)
        
        for output in outputs {
            output.buffer!.replaceValues(outValue)
        }
    }
    
}
