//
//  CrosscorrelationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import Accelerate

final class CrosscorrelationAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        var a: [Double]
        var b: [Double]
        
        let firstBuffer = inputs.first!.buffer!
        let secondBuffer = inputs[1].buffer!
        
        //Put the larger input in a and the smaller one in b
        if (firstBuffer.count > secondBuffer.count) {
            a = firstBuffer.toArray()
            b = secondBuffer.toArray()
        }
        else {
            b = firstBuffer.toArray()
            a = secondBuffer.toArray()
        }
        
        let compRange = a.count-b.count
        
        
        let result = UnsafeMutablePointer<Double>.alloc(compRange)
        
        vDSP_convD(a, 1, b, 1, result, 1, vDSP_Length(compRange), vDSP_Length(b.count))
        
        let array = Array(UnsafeBufferPointer(start: result, count: compRange))
        
        result.destroy()
        result.dealloc(compRange)
        
        
        #if DEBUG_ANALYSIS
            debug_noteInputs(["a" : a, "b" : b])
        #endif
        
//        var append: [Double] = []
//        let compRangeD = Double(compRange)
//        //The actual calculation
//        for i in 0..<compRange {
//            var sum = 0.0
//            for j in 0..<b.count {
//                sum += a[j+i]*b[j];
//            }
//            
//            let v = sum/compRangeD
//            
//            append.append(v)
//        }

        #if DEBUG_ANALYSIS
            debug_noteOutputs(array)
        #endif
        
        let outBuffer = outputs.first!.buffer!
        outBuffer.replaceValues(array)
    }
}
