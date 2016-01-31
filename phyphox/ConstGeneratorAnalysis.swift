//
//  ConstGeneratorAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class ConstGeneratorAnalysis: ExperimentAnalysisModule {

    override func update() {
        var value: Double = 0
        var length: Int = 0
        
        for input in inputs {
            if input.asString == "value" {
                if let v = input.getSingleValue() {
                    value = v
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
        
        let append = [Double](count: length, repeatedValue: value)
        
        let max = value
        let min = value
        
        outBuffer.replaceValues(append, max: max, min: min)
    }
}
