//
//  RampGeneratorAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class RampGeneratorAnalysis: ExperimentAnalysisModule {

    override func update() {
        var start: Double = 0
        var stop: Double = 0
        var length: Int = 0
        
        for input in inputs {
            if input.asString == "start" {
                start = input.getSingleValue()
            }
            else if input.asString == "stop" {
                stop = input.getSingleValue()
            }
            else if input.asString == "length" {
                length = Int(input.getSingleValue())
            }
            else {
                print("Error: Invalid analysis input: \(input.asString)")
            }
        }
        
        let outBuffer = outputs.first!.buffer!
        
        outBuffer.clear()
        
        if length == 0 {
            length = outBuffer.size
        }
        
        for i in 0..<length {
            outBuffer.append(start+(stop-start)/Double((length-1)*i))
        }
    }
}
