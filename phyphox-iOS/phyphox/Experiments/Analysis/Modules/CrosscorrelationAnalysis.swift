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
    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [
            AnalysisIOSlot(name: "in", asRequired: false, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 2, maxCount: 2)
        ], outputs: [
            AnalysisIOSlot(name: "out", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
        ])
    }
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
        
        //An empty input is an error state yielding an empty output (matching Android) - the
        //convolution below would otherwise emit zeros
        guard !firstBuffer.isEmpty && !secondBuffer.isEmpty else {
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

        //Raw correlation sums, without any normalization - matching the default of
        //numpy.correlate, scipy.signal.correlate and MATLAB xcorr
        var result = [Double](repeating: 0.0, count: compRange)

        vDSP_convD(a, 1, b, 1, &result, 1, vDSP_Length(compRange), vDSP_Length(b.count))
        
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
