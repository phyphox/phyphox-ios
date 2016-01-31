//
//  GCDAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class GCDAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        var lastValues: [Double] = []
        var bufferIterators: [IndexingGenerator<Array<Double>>] = []
        
        for (i, input) in inputs.enumerate() {
            if let fixed = input.value {
                lastValues.append(fixed)
            }
            else {
                bufferIterators.append(input.buffer!.generate())
                lastValues.append(0.0)
            }
            
            if (i == 1) {
                break
            }
        }
        
        let outBuffer = outputs.first!.buffer!
        
        var append: [Double] = []
        
        var max: Double? = nil
        var min: Double? = nil
        
        for _ in 0..<outBuffer.size {
            var didGetInput = false
            
            for (j, var iterator) in bufferIterators.enumerate() {
                if let next = iterator.next() {
                    lastValues[j] = next
                    didGetInput = true
                }
            }
            
            var a = round(lastValues.first!)
            var b = round(lastValues[1])
            
            //Euclid's algorithm (modern iterative version)
            while (b > 0) {
                let tmp = b;
                b = a % b;
                a = tmp;
            }
            
            if didGetInput {
                if max == nil || a > max {
                    max = a
                }
                
                if min == nil || a < min {
                    min = a
                }
                
                append.append(a)
            }
            else {
                break;
            }
        }
        
        outBuffer.replaceValues(append, max: max, min: min)
    }
}
