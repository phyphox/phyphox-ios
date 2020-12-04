//
//  IntegrationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

final class IntegrationAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        guard let firstInput = inputs.first else { return }

        let inputBuffer: DataBuffer

        switch firstInput {
        case .buffer(buffer: let buffer, usedAs: _, clear: _):
            inputBuffer = buffer
        case .value(value: _, usedAs: _):
            return
        }

        let inArray = inputBuffer.toArray()
        let count = inArray.count
        
        var result: [Double]
        
        if count == 0 {
            result = []
        }
        else {
            result = [Double](repeating: 0.0, count: count)
            
            var factor = 1.0
            vDSP_vrsumD(inArray, 1, &factor, &result, 1, vDSP_Length(count))
            
            var repeatedVal = inArray[0]
            
            if repeatedVal != 0.0 {
                vDSP_vsaddD(result, 1, &repeatedVal, &result, 1, vDSP_Length(count))
            }
        }
        
        beforeWrite()

        for output in outputs {
            switch output {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(result)
                }
                else {
                    buffer.appendFromArray(result)
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
    }
}
