//
//  DivisionAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

class DivisionAnalysis: ExperimentAnalysis {
    
    override func update() {
        var lastValues: [Double] = []
        var bufferIterators: [AnyGenerator<Double>] = []
        
        for (i, input) in inputs.enumerate() {
            if let fixed = fixedValues[i] {
                lastValues.append(fixed)
            }
            else {
                bufferIterators.append(getBufferForKey(input)!.generate())
                lastValues.append(0.0)
            }
        }
        
        outputs.first!.clear()
        
        for _ in 0...outputs.first!.size-1 {
            var neutral = 1.0
            var didGetInput = false
            
            for (j, iterator) in bufferIterators.enumerate() {
                if let next = iterator.next() {
                    lastValues[j] = next
                    didGetInput = true
                }
                
                if (j == 0) {
                    neutral = lastValues[j]; //First value: Get value even if there is no value left in the buffer
                }
                else {
                    neutral /= lastValues[j]; //Subtracted values: Get value even if there is no value left in the buffer
                }
            }
            
            if didGetInput {
                outputs.first!.append(neutral)
            }
            else {
                break;
            }
        }
    }
}
