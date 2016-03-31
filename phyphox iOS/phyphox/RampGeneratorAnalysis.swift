//
//  RampGeneratorAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import Accelerate

final class RampGeneratorAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        var start = 0.0
        var stop = 0.0
        var length = 0
        
        for input in inputs {
            if input.asString == "start" {
                if let v = input.getSingleValue() {
                    start = v
                }
                else {
                    print("Ramp generator error")
                    return
                }
            }
            else if input.asString == "stop" {
                if let v = input.getSingleValue() {
                    stop = v
                }
                else {
                    print("Ramp generator error")
                    return
                }
            }
            else if input.asString == "length" {
                if let v = input.getSingleValue() {
                    length = Int(v)
                }
                else {
                    print("Ramp generator error")
                    return
                }
            }
            else {
                print("Error: Invalid analysis input: \(input.asString)")
            }
        }

        if length == 0 {
            length = outputs.first!.buffer!.size
        }
        
        var result = [Double](count: length, repeatedValue: 0.0)
        
        #if DEBUG_ANALYSIS
            debug_noteInputs(["start" : start, "stop" : stop, "length" : length])
        #endif
        
        var step = (stop-start)/Double(length-1)
        
        vDSP_vrampD(&start, &step, &result, 1, vDSP_Length(length))
        
        #if DEBUG_ANALYSIS
            debug_noteOutputs(result)
        #endif
        
        for output in outputs {
            if output.clear {
                output.buffer!.replaceValues(result)
            }
            else {
                output.buffer!.appendFromArray(result)
            }
        }
    }
}
