//
//  FFTAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import Accelerate

final class FFTAnalysis: ExperimentAnalysisModule {
    private var fftSetup: vDSP_DFT_SetupD!
    
    deinit {
        if fftSetup != nil {
            vDSP_DFT_DestroySetupD(fftSetup!)
            fftSetup = nil
        }
    }
    
    override func update() {
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
        
        let hasImagInBuffer = imagInput != nil
        
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
        
        let bufferCount = imagInput != nil ? min(realInput.count, imagInput!.count) : realInput.count
        
        let count = vDSP_Length(pow(2.0, log2(Double(bufferCount))))
        let countI = Int(count)
        
//        if hasImagInBuffer {
//            if imagOutput != nil { //cpx -> cpx
                fftSetup = vDSP_DFT_zop_CreateSetupD(fftSetup ?? nil, count, vDSP_DFT_Direction.FORWARD)
//            }
//            else { //cpx -> real
//                fftSetup = vDSP_DFT_zrop_CreateSetupD(fftSetup ?? nil, count, vDSP_DFT_Direction.INVERSE)
//            }
//        }
//        else { //real -> cpx
//            fftSetup = vDSP_DFT_zrop_CreateSetupD(fftSetup ?? nil, count, vDSP_DFT_Direction.FORWARD)
//        }
        
        let realInputArray = realInput.toArray()
        let imagInputArray = (hasImagInBuffer ? imagInput!.toArray() : [Double](count: countI, repeatedValue: 0.0))
        
        var realOutputArray = [Double](count: countI, repeatedValue: 0.0)
        var imagOutputArray = realOutputArray
        
        vDSP_DFT_ExecuteD(fftSetup, realInputArray, imagInputArray, &realOutputArray, &imagOutputArray)
        
        if !hasImagInBuffer {
            realOutputArray = Array(realOutputArray[0..<countI/2])
            imagOutputArray = Array(imagOutputArray[0..<countI/2])
        }
        
        if realOutput != nil {
            realOutput!.appendFromArray(realOutputArray)
        }
        
        if imagOutput != nil {
            imagOutput!.appendFromArray(imagOutputArray)
        }
        
        /*
        let count = Int(kiss_fft_next_fast_size((Int32(bufferCount)+1) >> 1) << 1)
        
        var cpxInputs: [DOUBLE_COMPLEX] = []
        inputs.reserveCapacity(count)
        
        let cpxZero = DOUBLE_COMPLEX(real: 0.0, imag: 0.0)
        
        if hasImagInBuffer {
            for i in 0..<count {
                if count > bufferCount {
                    cpxInputs.append(cpxZero)
                }
                else {
                    cpxInputs.append(DOUBLE_COMPLEX(real: realInput[i], imag: imagInput![i]))
                }
            }
        }
        else {
            for i in 0..<count {
                if count > bufferCount {
                    cpxInputs.append(cpxZero)
                }
                else {
                    cpxInputs.append(DOUBLE_COMPLEX(real: realInput[i], imag: 0.0))
                }
            }
        }
        
        let fft = kiss_fft_alloc(Int32(count), 0, nil, nil)
        
        var out = [kiss_fft_cpx](count: count, repeatedValue: cpxZero)
        
        kiss_fft(fft, &cpxInputs, &out)
        
        if !hasImagInBuffer {
            out = Array(out[0..<count/2])
        }
        

 
        if realOutput != nil {
            let mapped = out.map{ Double($0.r) }
            
            realOutput!.appendFromArray(mapped)
        }
        
        if imagOutput != nil {
            let mapped = out.map{ Double($0.i) }
            
            imagOutput!.appendFromArray(mapped)
        }*/
    }
}
