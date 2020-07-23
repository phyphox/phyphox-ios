//
//  CrosscorrelationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

final class CrosscorrelationAnalysis: ExperimentAnalysisModule {
    override func update() {
        var a: [Double]
        var b: [Double]
        
        let firstBuffer: DataBuffer
        let secondBuffer: DataBuffer

        guard inputs.count == 2 else { return }

        switch inputs[0] {
        case .buffer(buffer: let buffer, usedAs: _, clear: _):
            firstBuffer = buffer
        case .value(value: _, usedAs: _):
            return
        }

        switch inputs[1] {
        case .buffer(buffer: let buffer, usedAs: _, clear: _):
            secondBuffer = buffer
        case .value(value: _, usedAs: _):
            return
        }
        
        //Put the larger input in a and the smaller one in b
        if firstBuffer.count > secondBuffer.count {
            a = firstBuffer.toArray()
            b = secondBuffer.toArray()
        }
        else {
            b = firstBuffer.toArray()
            a = secondBuffer.toArray()
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
