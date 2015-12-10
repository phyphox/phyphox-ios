//
//  LCDAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class LCDAnalysis: ExperimentAnalysis {
    
    override func update() {
        var lastValues: [Double] = []
        var bufferIterators: [IndexingGenerator<Array<Double>>] = []
        
        for (i, input) in inputs.enumerate() {
            if let fixed = fixedValues[i] {
                lastValues.append(fixed)
            }
            else {
                bufferIterators.append(getBufferForKey(input)!.generate())
                lastValues.append(0.0)
            }
            
            if (i == 1) {
                break;
            }
        }
        
        outputs.first!.clear()
        
        for _ in 0..<outputs.first!.size {
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
                outputs.first!.append(a0*(b0/a))
            }
            else {
                break;
            }
        }
    }
}
