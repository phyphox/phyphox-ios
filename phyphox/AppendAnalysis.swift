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
        
        outBuffer.clear()
        
        for input in inputs {
            if let b = input.buffer {
                for val in b {
                    outBuffer.append(val)
                }
            }
        }
    }
}
