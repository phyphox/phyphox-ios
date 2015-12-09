//
//  CrosscorrelationAnaylsis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class CrosscorrelationAnaylsis: ExperimentAnalysis {
    
    override func update() {
        var a: [Double]
        var b: [Double]

        let firstBuffer = getBufferForKey(inputs.first!)!
        let secondBuffer = getBufferForKey(inputs[1])!
        
        //Put the larger input in a and the smaller one in b
        if (firstBuffer.count > secondBuffer.count) {
            a = firstBuffer.toArray()
            b = secondBuffer.toArray()
        }
        else {
            b = firstBuffer.toArray()
            a = secondBuffer.toArray()
        }
        
        outputs.first!.clear()
        
        let compRange = a.count-b.count
        
        //The actual calculation
        for i in 0...compRange-1 {
            var sum = 0.0
            for j in 0...b.count-1 {
                sum += a[j+i]*b[j];
            }
            
            outputs.first!.append(sum/Double(compRange))
        }
    }
}
