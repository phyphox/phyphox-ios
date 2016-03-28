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
        var start: Double = 0
        var stop: Double = 0
        var length: Int = 0
        
        for input in inputs {
            if input.asString == "start" {
                if let v = input.getSingleValue() {
                    start = v
                }
                else {
                    return
                }
            }
            else if input.asString == "stop" {
                if let v = input.getSingleValue() {
                    stop = v
                }
                else {
                    return
                }
            }
            else if input.asString == "length" {
                if let v = input.getSingleValue() {
                    length = Int(v)
                }
                else {
                    return
                }
            }
            else {
                print("Error: Invalid analysis input: \(input.asString)")
            }
        }
        
        let outBuffer = outputs.first!.buffer!
        
        if length == 0 {
            length = outBuffer.size
        }
        
        var out = [Double](count: length, repeatedValue: 0.0)
        
        #if DEBUG_ANALYSIS
            debug_noteInputs(["start" : start, "stop" : stop, "length" : length])
        #endif
        
        var step = (stop-start)/Double(length-1)
        
        vDSP_vrampD(&start, &step, &out, 1, vDSP_Length(length))
        
        #if DEBUG_ANALYSIS
            debug_noteOutputs(out)
        #endif
        
        outBuffer.replaceValues(out)
    }
}
