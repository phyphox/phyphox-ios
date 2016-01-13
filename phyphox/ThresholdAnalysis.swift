//
//  ThresholdAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class ThresholdAnalysis: ExperimentAnalysisModule {
    let falling: Bool
    
    override init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String : AnyObject]?) {
        falling = boolFromXML(additionalAttributes, key: "falling", defaultValue: false)
        
        super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        var threshold = 0.0
        
        var xIn: DataBuffer?
        var yIn: DataBuffer!
        
        for input in inputs {
            if input.asString == "threshold" {
               threshold = input.getSingleValue()
            }
            else if input.asString == "y" {
                yIn = input.buffer
            }
            else if input.asString == "x" {
                xIn = input.buffer
            }
            else {
                print("Error: Invalid analysis input: \(input.asString)")
            }
        }
        
        let out = outputs.first!.buffer
        
        var x: Double?
        
        for (i, value) in yIn.enumerate() {
            if (falling ? value < threshold : value > threshold) {
                if xIn != nil && i < xIn!.size {
                    x = xIn![i]
                }
                else {
                    x = Double(i)
                }
                
                break
            }
        }
        
        if x == nil {
            return
        }
        
        out!.append(x!)
    }
}
