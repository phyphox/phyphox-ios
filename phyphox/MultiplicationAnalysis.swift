//
//  MultiplicationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class MultiplicationAnalysis: ExperimentAnalysisModule {
    
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
        
        outBuffer.clear()
        
        for _ in 0..<outBuffer.size {
            var neutral = 1.0
            var didGetInput = false
            
            for (j, var iterator) in bufferIterators.enumerate() {
                if let next = iterator.next() {
                    lastValues[j] = next
                    didGetInput = true
                }
                
                neutral *= lastValues[j]
            }
            
            if didGetInput {
                outBuffer.append(neutral)
            }
            else {
                break;
            }
        }
    }
}
