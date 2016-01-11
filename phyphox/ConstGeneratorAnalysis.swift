//
//  ConstGeneratorAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class ConstGeneratorAnalysis: ExperimentAnalysis {

    override func update() {
        var value: Double = 0
        var length: Int = 0
        
        for input in inputs {
            if input.asString == "value" {
                value = input.getSingleValue()
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
        
        for _ in 0..<length {
            outBuffer.append(value)
        }
    }
}
