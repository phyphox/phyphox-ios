//
//  ExperimentComplexUpdateValueAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 31.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation
import Surge

/**
 An abstract analysis module that takes multiple inputs (with an optional prioritized input), brings them all to the same size and runs a given closure with all the input arrays. The closure must return an array of Doubles.
 */
class ExperimentComplexUpdateValueAnalysis: ExperimentAnalysisModule {
    
    func updateAllWithMethod(method: [[Double]] -> [Double], priorityInputKey: String?) {
        var values: [[Double]] = []
        var maxCount = 0
        
        for input in inputs {
            if let fixed = input.value {
                if priorityInputKey != nil && input.asString == priorityInputKey! {
                    values.insert([fixed], atIndex: 0)
                }
                else {
                    values.append([fixed])
                }
                
                maxCount = Swift.max(maxCount, 1)
            }
            else {
                let array = input.buffer!.toArray()
                
                if priorityInputKey != nil && input.asString == priorityInputKey! {
                   values.insert(array, atIndex: 0)
                }
                else {
                    values.append(array)
                }
                
                maxCount = Swift.max(maxCount, array.count)
            }
        }
        
        for var array in values {
            let delta = maxCount-array.count
            
            if delta > 0 {
                array.appendContentsOf([Double](count: delta, repeatedValue: array.last ?? 0.0))
            }
        }
        
        let out = method(values)
        
        let max = Surge.max(out)
        let min = Surge.min(out)
        
        for output in outputs {
            output.buffer!.replaceValues(out, max: max, min: min)
        }
    }

}
