//
//  MaxAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class MaxAnalysis: ExperimentAnalysis {
    
    override func update() {
        //TODO: Update
        var iterators: [IndexingGenerator<Array<Double>>] = []
        
        for  input in inputs {
            if let b = input.buffer {
                iterators.append(b.generate())
            }
        }
        
       var max = -Double.infinity
       var x = max //The x location of the maximum
       var currentX = -1.0; //Current x during iteration
        
        while let v = iterators[0].next() { //For each value of input1
            //if input2 is given set x to this value. Otherwise generate x by incrementing it by 1.
            if iterators.count > 1 {
                if let val = iterators[1].next() {
                    currentX = val
                }
                else {
                    currentX += 1.0
                }
            }
            else {
                currentX += 1.0
            }
            
            //Is the current value bigger then the previous maximum?
            if (v > max) {
                //Set maximum and location of maximum
                max = v;
                x = currentX;
            }
        }
        
        //Done. Append result to output1 and output2 if used.
        
        for out in outputs {
            out.buffer!.append(x)
        }
    }
}
