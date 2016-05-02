//
//  ThresholdAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

final class ThresholdAnalysis: ExperimentAnalysisModule {
    private let falling: Bool
    
    private var xIn: DataBuffer?
    private var yIn: DataBuffer!
    private var thresholdIn: ExperimentAnalysisDataIO?
    
    override init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String : AnyObject]?) {
        falling = boolFromXML(additionalAttributes, key: "falling", defaultValue: false)

        for input in inputs {
            if input.asString == "threshold" {
                thresholdIn = input
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
        
        super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        var threshold = 0.0
        
        if let v = thresholdIn?.getSingleValue() {
            threshold = v
        }
        
        var x: Double?
        var last = Double.NaN
        
        for (i, value) in yIn.enumerate() {
            if (falling ? (value < threshold && last > threshold) : (value > threshold && last < threshold)) {
                if let v = xIn?.objectAtIndex(i) {
                    x = v
                }
                else {
                    x = Double(i)
                }
                break
            }
            last = value
        }
        
        guard x != nil else {
            for output in outputs {
                if output.clear {
                    output.buffer!.replaceValues([])
                }
            }
            
            return
        }
        
        for output in outputs {
            if output.clear {
                output.buffer!.replaceValues([x!])
            }
            else {
                output.buffer!.append(x!)
            }
        }
    }
}
