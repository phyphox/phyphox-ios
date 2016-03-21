//
//  GaussSmoothAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class GaussSmoothAnalysis: ExperimentAnalysisModule {
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
    
    override init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String : AnyObject]?) {
        sigma = floatTypeFromXML(additionalAttributes, key: "sigma", defaultValue: 3.0)
        super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        var y: [Double] = inputs.first!.buffer!.toArray() //Get array for random access

        let outBuffer = outputs.first!.buffer!
        
        var append: [Double] = []
        
        for i in 0..<y.count {
            var sum = 0.0
            for j in -calcWidth...calcWidth {
                let k = i+j
                if (k >= 0 && k < y.count) {
                    sum += gauss[j+calcWidth]*y[k];
                }
            }
            
            append.append(sum)
        }
        
        outBuffer.replaceValues(append)
    }
}
