//
//  LCMAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class LCMAnalysis: ExperimentAnalysis {
    
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
        
        outBuffer.clear()
        
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
            
            let a0 = a;
            let b0 = b;
            
            //Euclid's algorithm (modern iterative version)
            while (b > 0) {
                let tmp = b;
                b = a % b;
                a = tmp;
            }
            
            if didGetInput {
                outBuffer.append(a0*(b0/a))
            }
            else {
                break;
            }
        }
    }
}
