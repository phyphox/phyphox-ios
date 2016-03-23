//
//  FFTAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class FFTAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        let hasImagInBuffer = inputs.count > 1
        
        var realInput: DataBuffer!
        var imagInput: DataBuffer?
        
        for input in inputs {
            if input.asString == "im" {
                imagInput = input.buffer
            }
            else {
                realInput = input.buffer
            }
        }
        
        let count = imagInput != nil ? min(realInput.count, imagInput!.count) : realInput.count
        
        var cpxInputs: [kiss_fft_cpx] = []
        inputs.reserveCapacity(count)
        
        if hasImagInBuffer {
            for i in 0..<count {
                cpxInputs.append(kiss_fft_cpx(r: Float(realInput[i]), i: Float(imagInput![i])))
            }
        }
        else {
            for i in 0..<count {
                cpxInputs.append(kiss_fft_cpx(r: Float(realInput[i]), i: 0.0))
            }
        }
        
        let fft = kiss_fft_alloc(Int32(count), 0, nil, nil)
        
        let cpxOutput = UnsafeMutablePointer<kiss_fft_cpx>.alloc(count)
        
        kiss_fft(fft, &cpxInputs, cpxOutput)
        
        let out = Array(UnsafeBufferPointer(start: cpxOutput, count: count))
        
        cpxOutput.destroy()
        cpxOutput.dealloc(count)
        
        var realOutput: DataBuffer?
        var imagOutput: DataBuffer?
        
        for output in outputs {
            if output.asString == "im" {
                imagOutput = output.buffer
            }
            else {
                realOutput = output.buffer
            }
        }
        
        if realOutput != nil {
            realOutput!.appendFromArray(out.map({ (cpx) -> Double in
                return Double(cpx.r)
            }))
        }
        
        if imagOutput != nil {
            imagInput!.appendFromArray(out.map({ (cpx) -> Double in
                return Double(cpx.i)
            }))
        }
    }
}
