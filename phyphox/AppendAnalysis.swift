//
//  AppendAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class AppendAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        let outBuffer = outputs.first!.buffer!
        
        var append: [Double] = []
        
        var max: Double? = nil
        var min: Double? = nil
        
        for input in inputs {
            if let b = input.buffer {
                for val in b {
                    if max == nil || val > max {
                        max = val
                    }
                    
                    if min == nil || val < min {
                        min = val
                    }
                    
                    append.append(val)
                }
            }
        }
        
        outBuffer.updateMaxAndMin(max, min: min)
        outBuffer.replaceValues(append)
    }
}
