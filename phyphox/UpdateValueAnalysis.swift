//
//  UpdateValueAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 21.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

class UpdateValueAnalysis: ExperimentAnalysisModule {
    
    internal func updateWithMethod(method: (Double) -> Double) {
        let input = inputs.first!
        
        let outBuffer = outputs.first!.buffer!
        
        outBuffer.clear()
        
        if let buffer = input.buffer {
            for val in buffer {
                outBuffer.append(method(val))
            }
        }
        else {
            outBuffer.append(method(input.value!))
        }
    }
}
