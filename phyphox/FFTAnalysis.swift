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
        
        let bufferCount = imagInput != nil ? min(realInput.count, imagInput!.count) : realInput.count
        
        let count = Int(kiss_fft_next_fast_size((Int32(bufferCount)+1) >> 1) << 1)
        
        var cpxInputs: [kiss_fft_cpx] = []
        inputs.reserveCapacity(count)
        
        let cpxZero = kiss_fft_cpx(r: 0.0, i: 0.0)
        
        if hasImagInBuffer {
            for i in 0..<count {
                if count > bufferCount {
                    cpxInputs.append(cpxZero)
                }
                else {
                    cpxInputs.append(kiss_fft_cpx(r: Float(realInput[i]), i: Float(imagInput![i])))
                }
            }
        }
        else {
            for i in 0..<count {
                if count > bufferCount {
                    cpxInputs.append(cpxZero)
                }
                else {
                    cpxInputs.append(kiss_fft_cpx(r: Float(realInput[i]), i: 0.0))
                }
            }
        }
        
        let fft = kiss_fft_alloc(Int32(count), 0, nil, nil)
        
        var out = [kiss_fft_cpx](count: count, repeatedValue: cpxZero)
        
        kiss_fft(fft, &cpxInputs, &out)
        
        if !hasImagInBuffer {
            out = Array(out[0..<count/2])
        }
        
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
            let mapped = out.map{ Double($0.r) }
            
            realOutput!.appendFromArray(mapped)
        }
        
        if imagOutput != nil {
            let mapped = out.map{ Double($0.i) }
            
            imagOutput!.appendFromArray(mapped)
        }
    }
}
