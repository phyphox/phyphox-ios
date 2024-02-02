//
//  IntegrationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

final class IntegrationAnalysis: AutoClearingExperimentAnalysisModule {
    
    override func update() {
        guard let firstInput = inputs.first else { return }

        let inArray: [Double]

        switch firstInput {
        case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
            inArray = data.data
        case .value(value: _, usedAs: _):
            return
        }

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
        
        for output in outputs {
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(result)
            }
        }
    }
}
