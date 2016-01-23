//
//  AdditionAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class AdditionAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        var lastValues: [Double] = []
        var bufferIterators: [IndexingGenerator<Array<Double>>] = []
        
        for input in inputs {
            if let fixed = input.value {
                lastValues.append(fixed)
            }
            else {
                bufferIterators.append(input.buffer!.generate())
                lastValues.append(0.0)
            }
        }
        
        let outBuffer = outputs.first!.buffer!
        
        var append: [Double] = []
        
        var max: Double? = nil
        var min: Double? = nil
        
        for _ in 0..<outBuffer.size {
            var neutral = 0.0
            var didGetInput = false
            
            for (j, var iterator) in bufferIterators.enumerate() {
                if let next = iterator.next() {
                    lastValues[j] = next
                    didGetInput = true
                }
                
                neutral += lastValues[j]
            }
            
            if didGetInput {
                if max == nil || neutral > max {
                    max = neutral
                }
                
                if min == nil || neutral < min {
                    min = neutral
                }
                
                append.append(neutral)
            }
            else {
                break;
            }
        }
        
        outBuffer.updateMaxAndMin(max, min: min)
        outBuffer.replaceValues(append)
    }
}
