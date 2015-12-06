//
//  GaussSmoothAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class GaussSmoothAnalysis: ExperimentAnalysis {
    var calcWidth: Int = 0
    var gauss: [Double] = []
    
    var sigma: Double {
        didSet {
            calcWidth = Int(round(sigma*3.0))
            
            for i in -calcWidth...calcWidth {
                let d = Double(i)
                gauss[i+calcWidth] = exp(-(d/sigma*d/sigma)/2.0)/(sigma*sqrt(2.0*M_PI)) //Gauß!
            }
        }
    }
    
    override init(experiment: Experiment, inputs: [String], outputs: [DataBuffer]) {
        sigma = 3.0
        super.init(experiment: experiment, inputs: inputs, outputs: outputs)
    }
    
    override func update() {
        var y: [Double] = getBufferForKey(inputs.first!)!.toArray()! //Get array for random access

        //Clear output
        outputs.first!.clear()
        
        for i in 0...y.count-1 {
            var sum = 0.0
            for j in -calcWidth...calcWidth {
                let k = i+j
                if (k >= 0 && k < y.count) {
                    sum += gauss[j+calcWidth]*y[k];
                }
            }
            
            outputs.first!.append(sum)
        }
    }
}
