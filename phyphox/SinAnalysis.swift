//
//  SinAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class SinAnalysis: ExperimentAnalysis {
    
    override func update() {
        var iterator: AnyGenerator<Double>? = nil
        var lastValue: Double = 0.0
        
        //Get value or iterator
        if let val = fixedValues[0] {
            lastValue = val
        }
        else {
            //iterator
            iterator = getBufferForKey(inputs.first!)!.generate()
        }
        
        outputs.first!.clear()
        
        if (iterator == nil) {
            outputs.first!.append(sin(lastValue))
        }
        else {
            while let next = iterator!.next() { //For each output value or at least once for values
                outputs.first!.append(sin(next))
            }
        }
    }
}

