//
//  FFTAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import Accelerate

//For vDSP_DFT_zop_CreateSetup
func nextFFTSize(c: Int) -> Int {
    var options = [Int]()
    let d = Double(c)
    
    //Length = 2^n.
    let n = ceil(log2(d))
    
    let res = Int(pow(2.0, n))
    
    //print("[For: \(c)] 2^\(n) = \(res)")
    
    options.append(res)
    
    //or Length = f * 2^n, where f is 3, 5, or 15 and 3 <= n.
    let fs = [3.0, 5.0, 15.0]
    
    for f in fs {
        let e = d/f
        
        let nn = ceil(log2(e))
        
        let b = pow(2.0, nn)
        
        if 3 <= nn {
            let re = Int(f*b)
            
            //print("[For: \(c)] \(f)*2^\(nn) = \(re)")
            
            options.append(re)
        }
    }
    
    //Select best size
    var selectedOption = 0
    
    var minOffset = Int.max
    
    for option in options {
        if option < c {
            print("Error, next fft size should be >= input size")
            continue
        }
        
        let offset = option-c
        
        if offset < minOffset {
            minOffset = offset
            selectedOption = option
        }
    }
    
    return selectedOption
}


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
        
        measure { 
            
        
        
        let bufferCount = imagInput != nil ? min(realInput.count, imagInput!.count) : realInput.count
        
        let count = vDSP_Length(nextFFTSize(bufferCount))
        let countI = Int(count)

        self.fftSetup = vDSP_DFT_zop_CreateSetupD(self.fftSetup ?? nil, count, vDSP_DFT_Direction.FORWARD)
        
        var realInputArray = realInput.toArray()
        var imagInputArray = (hasImagInBuffer ? imagInput!.toArray() : [Double](count: countI, repeatedValue: 0.0))
        
        //Fill arrays if needed
        let realOffset = countI-realInputArray.count
        
        if realOffset > 0 {
            realInputArray.appendContentsOf(Repeat(count: realOffset, repeatedValue: 0.0))
        }
        
        let imagOffset = countI-imagInputArray.count
        
        if imagOffset > 0 {
            imagInputArray.appendContentsOf(Repeat(count: imagOffset, repeatedValue: 0.0))
        }
        
        //Run DFT
        var realOutputArray = [Double](count: countI, repeatedValue: 0.0)
        var imagOutputArray = realOutputArray
        
        vDSP_DFT_ExecuteD(self.fftSetup, realInputArray, imagInputArray, &realOutputArray, &imagOutputArray)
        
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
