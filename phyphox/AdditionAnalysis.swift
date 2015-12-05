//
//  AdditionAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

class AdditionAnalysis: ExperimentAnalysis {
    
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
            var neutral = 0.0
            var didGetInput = false
            
            for (j, iterator) in bufferIterators.enumerate() {
                if let next = iterator.next() {
                    lastValues[j] = next
                    didGetInput = true
                }
                
                neutral += lastValues[j]
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
