//
//  PowerAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class PowerAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        var lastValues: [Double] = []
        var bufferIterators: [IndexingGenerator<Array<Double>>] = []
        
        for input in inputs {
            if let fixed = input.value {
                if input.asString == "base" {
                    lastValues.insert(fixed, atIndex: 0)
                }
                else {
                    lastValues.append(fixed)
                }
            }
            else {
                if input.asString == "base" {
                    bufferIterators.insert(input.buffer!.generate(), atIndex: 0)
                    lastValues.insert(0.0, atIndex: 0)
                }
                else {
                    bufferIterators.append(input.buffer!.generate())
                    lastValues.append(0.0)
                }
            }
        }
        
        let outBuffer = outputs.first!.buffer!
        
        var append: [Double] = []
        
        var max: Double? = nil
        var min: Double? = nil
        
        for _ in 0..<outBuffer.size {
            var neutral = 1.0
            var didGetInput = false
            
            for (j, var iterator) in bufferIterators.enumerate() {
                if let next = iterator.next() {
                    lastValues[j] = next
                    didGetInput = true
                }
                
                if (j == 0) {
                    neutral = lastValues[j]; //First value: Get value even if there is no value left in the buffer
                }
                else {
                    neutral = pow(neutral, lastValues[j]); //Subtracted values: Get value even if there is no value left in the buffer
                }
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
