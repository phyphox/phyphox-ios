//
//  ExperimentComplexUpdateValueAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 31.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

/**
 An abstract analysis module that takes multiple inputs (with an optional prioritized input) and multiple outputs. For each index in the output the module takes the corresponding values from the inputs and calculates a value to be written to the output buffer.
 */
class ExperimentComplexUpdateValueAnalysis: ExperimentAnalysisModule {
    
    func updateWithMethod(method: ((first: Double, second: Double, initial: Bool) -> Double)?, outerMethod: ((currentValue: Double, values: [Double]) -> Double)?, neutralElement: Double, priorityInputKey: String?) {
        var lastValues: [Double] = [] //Stores the last value of each input.
        var buffers: [DataBuffer] = []
        
        for input in inputs {
            if let fixed = input.value {
                if priorityInputKey != nil && input.asString == priorityInputKey! {
                    lastValues.insert(fixed, atIndex: 0)
                }
                else {
                    lastValues.append(fixed)
                }
            }
            else {
                if priorityInputKey != nil && input.asString == priorityInputKey! {
                    buffers.insert(input.buffer!, atIndex: 0)
                    lastValues.insert(input.buffer!.last ?? neutralElement, atIndex: 0)
                }
                else {
                    buffers.append(input.buffer!)
                    lastValues.append(input.buffer!.last ?? neutralElement)
                }
            }
        }
        
        let outBuffer = outputs.first!.buffer!
        
        var append: [Double] = []
        
        var max: Double? = nil
        var min: Double? = nil
        
        for i in 0..<outBuffer.size {
            var neutral = neutralElement
            var didGetNewValue = false
            
            for (j, buffer) in buffers.enumerate() {
                if let v = buffer.objectAtIndex(i, async: true) {
                    lastValues[j] = v
                    didGetNewValue = true
                }
                
                if method != nil {
                    neutral = method!(first: neutral, second: lastValues[j], initial: j == 0)
                }
            }
            
            if outerMethod != nil {
                neutral = outerMethod!(currentValue: neutral, values: lastValues)
            }
            
            if didGetNewValue {
                if max == nil || neutral > max {
                    max = neutral
                }
                
                if min == nil || neutral < min {
                    min = neutral
                }
                
                append.append(neutral)
            }
            else {
                break
            }
        }
        
        outBuffer.replaceValues(append, max: max, min: min)
    }
}
