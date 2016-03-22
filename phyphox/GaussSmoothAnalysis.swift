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
    
    var sigma: Double = 0.0 {
        didSet {
            calcWidth = Int(round(sigma*3.0))
            
            gauss.removeAll()
            gauss.reserveCapacity(2*calcWidth+1)
            
            for i in 0...2*calcWidth {
                let d = Double(i)
                gauss.append(exp(-(d/sigma*d/sigma)/2.0)/(sigma*sqrt(2.0*M_PI))) //Gauß!
            }
        }
    }
    
    override init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String : AnyObject]?) {
        defer {
            sigma = floatTypeFromXML(additionalAttributes, key: "sigma", defaultValue: 3.0)
        }
        super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        var y: [Double] = inputs.first!.buffer!.toArray() //Get array for random access
        
        let outBuffer = outputs.first!.buffer!
        
        var append: [Double] = []
        
        #if DEBUG_ANALYSIS
            debug_noteInputs(["sigma" : sigma, "calcWidth" : calcWidth, "gauss" : gauss])
        #endif
        
        for i in 0..<y.count {
            var sum = 0.0
            for j in 0...2*calcWidth {
                let k = i+j
                if (k >= 0 && k < y.count) {
                    sum += gauss[j]*y[k];
                }
            }
            
            append.append(sum)
        }
        
        #if DEBUG_ANALYSIS
            debug_noteOutputs(append)
        #endif
        
        outBuffer.replaceValues(append)
    }
}
