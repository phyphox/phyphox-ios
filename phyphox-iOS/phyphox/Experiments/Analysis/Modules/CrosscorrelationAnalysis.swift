//
//  CrosscorrelationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

final class CrosscorrelationAnalysis: AutoClearingExperimentAnalysisModule {
    override func update() {
        var a: [Double]
        var b: [Double]
        
        let firstBuffer: [Double]
        let secondBuffer: [Double]

        guard inputs.count == 2 else { return }

        switch inputs[0] {
        case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
            firstBuffer = data.data
        case .value(value: _, usedAs: _):
            return
        }

        switch inputs[1] {
        case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
            secondBuffer = data.data
        case .value(value: _, usedAs: _):
            return
        }
        
        //Put the larger input in a and the smaller one in b
        if firstBuffer.count > secondBuffer.count {
            a = firstBuffer
            b = secondBuffer
        }
        else {
            b = firstBuffer
            a = secondBuffer
        }
        
        let compRange = a.count-b.count
        
        #if DEBUG_ANALYSIS
            debug_noteInputs(["a" : a, "b" : b])
        #endif
        
        var convResult = [Double](repeating: 0.0, count: compRange)
        
        vDSP_convD(a, 1, b, 1, &convResult, 1, vDSP_Length(compRange), vDSP_Length(b.count))

        var result = convResult
        
        //Normalize
        vDSP_vsdivD(convResult, 1, [Double(compRange)], &result, 1, vDSP_Length(convResult.count))
        
        #if DEBUG_ANALYSIS
            debug_noteOutputs(result)
        #endif

        for output in outputs {
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(result)
            }
        }
    }
}
