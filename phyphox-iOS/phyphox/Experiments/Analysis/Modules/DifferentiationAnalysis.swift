//
//  DifferentiationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

final class DifferentiationAnalysis: AutoClearingExperimentAnalysisModule {
    
    override func update() {
        guard let firstInput = inputs.first else { return }

        let inputValues: [Double]

        switch firstInput {
        case .buffer(buffer: _, data: let data, usedAs: _, clear: _):
            inputValues = data.data
        case .value(value: _, usedAs: _):
            return
        }

        var result: [Double]
        
        //Only use accelerate for long arrays
        if inputValues.count > 260 {
            var subtract = inputValues
            subtract.insert(0.0, at: 0)
            
            result = inputValues
            
            vDSP_vsubD(subtract, 1, inputValues, 1, &result, 1, vDSP_Length(inputValues.count))
            
            result.removeFirst()
        }
        else {
            result = []
            var first = true
            var last: Double!
            
            for value in inputValues {
                if first {
                    last = value
                    first = false
                    continue
                }
                
                let val = value-last
                
                result.append(val)
                
                last = value
            }
        }
        
        for output in outputs {
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, clear: _):
                buffer.appendFromArray(result)
            case .value(value: _, usedAs: _):
                break
            }
        }
    }
}
