//
//  FFTAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

/**
 For vDSP_DFT_zop_CreateSetup and vDSP_DFT_zrop_CreateSetup
 - Parameter minN: 3 for vDSP_DFT_zop_CreateSetup and 4 for vDSP_DFT_zrop_CreateSetup. Default 3.
 */
func nextFFTSize(_ c: Int, minN: Int = 3) -> Int {
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
        
        if minN <= Int(nn) {
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
    private var realInput: DataBuffer!
    private var imagInput: DataBuffer?
    
    private let hasImagInBuffer: Bool
    
    private var realOutput: ExperimentAnalysisDataIO?
    private var imagOutput: ExperimentAnalysisDataIO?
    
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: AttributeContainer) throws {
        for input in inputs {
            if input.asString == "im" {
                switch input {
                case .buffer(buffer: let buffer, usedAs: _, clear: _):
                    imagInput = buffer
                case .value(value: _, usedAs: _):
                    break
                }
            }
            else {
                switch input {
                case .buffer(buffer: let buffer, usedAs: _, clear: _):
                    realInput = buffer
                case .value(value: _, usedAs: _):
                    break
                }
            }
        }
        
        hasImagInBuffer = imagInput != nil
        
        for output in outputs {
            if output.asString == "im" {
                imagOutput = output
            }
            else {
                realOutput = output
            }
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        let bufferCount: Int

        if let imagInput = imagInput {
            bufferCount = min(realInput.memoryCount, imagInput.memoryCount)
        }
        else {
            bufferCount = realInput.memoryCount
        }

        var realOutputArray: [Double]
        var imagOutputArray: [Double]
        
        if bufferCount == 0 {
            realOutputArray = []
            imagOutputArray = []
        }
        else {
            let count = vDSP_Length(nextFFTSize(bufferCount))
            let countI = Int(count)
            
            var realInputArray = realInput.toArray()
            var imagInputArray = (hasImagInBuffer ? imagInput!.toArray() : [Double](repeating: 0.0, count: countI))
            
            //Fill arrays if needed
            let realOffset = countI-realInputArray.count
            
            if realOffset > 0 {
                realInputArray.append(contentsOf: [Double](repeating: 0.0, count: realOffset))
            }
            
            let imagOffset = countI-imagInputArray.count
            
            if imagOffset > 0 {
                imagInputArray.append(contentsOf: [Double](repeating: 0.0, count: imagOffset))
            }
            
            //Run DFT
            realOutputArray = [Double](repeating: 0.0, count: countI)
            imagOutputArray = realOutputArray
            
            //For now we recreate the DFT setup each time as it fixes some crashes.
            //Jonas noted before, that to fast calling of the DFT leads to crashes when reusing the setup, but I (Sebastian) was not able to reproduce this
            //Instead, I found that destroying the setup in deinit can lead to a crash as this is not thread safe and even if it was, the destruction might occur inbetween seting up the setup and actually executing the DFT
            //I would suggest reusing the setup for performance but make deinit thread safe, so it can only be called when analysis has been completed. However, for now the performance seems to be sufficient and memory allocation is no bottleneck whatsoever. So, let's stick to the clumsy, yet stable method for now.
            let dftSetup = vDSP_DFT_zop_CreateSetupD(nil, count, .FORWARD)
            vDSP_DFT_ExecuteD(dftSetup!, realInputArray, imagInputArray, &realOutputArray, &imagOutputArray)
            vDSP_DFT_DestroySetupD(dftSetup)
            
            if !hasImagInBuffer {
                realOutputArray = Array(realOutputArray[0..<countI/2])
                imagOutputArray = Array(imagOutputArray[0..<countI/2])
            }
        }

        beforeWrite()

        if let realOutput = realOutput {
            switch realOutput {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(realOutputArray)
                }
                else {
                    buffer.appendFromArray(realOutputArray)
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
        
        if let imagOutput = imagOutput {
            switch imagOutput {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(imagOutputArray)
                }
                else {
                    buffer.appendFromArray(imagOutputArray)
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
    }
}
