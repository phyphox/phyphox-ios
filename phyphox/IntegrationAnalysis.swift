//
//  IntegrationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class IntegrationAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        var sum = 0.0
        
        let outBuffer = outputs.first!.buffer!
        
        var append: [Double] = []
        
        let buffer = inputs.first!.buffer
        
        if buffer == nil {
            return
        }
        
        for value in buffer! {
            sum += value
            
            append.append(sum)
        }
        
        outBuffer.replaceValues(append)
    }
}
