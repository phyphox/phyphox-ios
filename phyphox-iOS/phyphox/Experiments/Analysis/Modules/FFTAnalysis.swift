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

//The Fourier modules fft, ifft, dft and idft (phyphox-docs rule fourier-transform-conventions): one slot layout, one kernel
//convention and one normalization attribute. fft/ifft run on vDSP, which only supports lengths f*2^n and therefore zero-pads
//every other length (fft-non-power-of-two-input, permanent); dft/idft are the exact transform for any length.
class FFTAnalysis: AutoClearingExperimentAnalysisModule {
    private static let reInSlot = AnalysisIOSlot(name: "re", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let imInSlot = AnalysisIOSlot(name: "im", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let reOutSlot = AnalysisIOSlot(name: "re", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let imOutSlot = AnalysisIOSlot(name: "im", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.reInSlot, Self.imInSlot], outputs: [Self.reOutSlot, Self.imOutSlot])
    }

    //Kernel sign: forward exp(-2*pi*i*k*n/N), inverse exp(+2*pi*i*k*n/N)
    class var inverse: Bool { return false }
    //Exact for any length (direct sum) instead of vDSP's padded f*2^n lengths
    class var exact: Bool { return false }

    //Which direction carries the 1/N factor, named as in NumPy
    enum Normalization: String, CaseInsensitiveAttributeDecodable, CaseIterable {
        case backward
        case forward
        case ortho
        case none

        func factor(count: Int, inverse: Bool) -> Double {
            switch self {
            case .backward: return inverse ? 1.0/Double(count) : 1.0
            case .forward: return inverse ? 1.0 : 1.0/Double(count)
            case .ortho: return 1.0/Double(count).squareRoot()
            case .none: return 1.0
            }
        }
    }

    let normalization: Normalization

    private var realInput: MutableDoubleArray!
    private var imagInput: MutableDoubleArray?
    
    private let hasImagInBuffer: Bool
    
    private var realOutput: ExperimentAnalysisDataOutput?
    private var imagOutput: ExperimentAnalysisDataOutput?
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        let attributes = additionalAttributes.attributes(keyedBy: String.self)
        normalization = try attributes.optionalValue(for: "normalization") ?? .backward

        let io = try Self.mapIO(inputs: inputs, outputs: outputs)
        realInput = io.data(Self.reInSlot)
        imagInput = io.data(Self.imInSlot)

        hasImagInBuffer = imagInput != nil

        realOutput = io.output(Self.reOutSlot)
        imagOutput = io.output(Self.imOutSlot)

        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        let bufferCount: Int

        if let imagInput = imagInput {
            bufferCount = min(realInput.data.count, imagInput.data.count)
        }
        else {
            bufferCount = realInput.data.count
        }

        var realOutputArray: [Double]
        var imagOutputArray: [Double]
        
        if bufferCount == 0 {
            realOutputArray = []
            imagOutputArray = []
        }
        else if bufferCount == 1 {
            //The transform of length one is the identity in both directions, every normalization factor being 1
            realOutputArray = [realInput.data[0]]
            imagOutputArray = [hasImagInBuffer ? imagInput!.data[0] : 0.0]
        }
        else if Self.exact {
            (realOutputArray, imagOutputArray) = directTransform(count: bufferCount)
        }
        else {
            let count = vDSP_Length(nextFFTSize(bufferCount))
            let countI = Int(count)
            
            var realInputArray = realInput.data
            var imagInputArray = (hasImagInBuffer ? imagInput!.data : [Double](repeating: 0.0, count: countI))
            
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
            //vDSP documents a minimum length of 8 but accepts 1, 2 and 4 (iOS 26.5); a rejected size yields empty output
            if let dftSetup = vDSP_DFT_zop_CreateSetupD(nil, count, Self.inverse ? .INVERSE : .FORWARD) {
                vDSP_DFT_ExecuteD(dftSetup, realInputArray, imagInputArray, &realOutputArray, &imagOutputArray)
                vDSP_DFT_DestroySetupD(dftSetup)

                //vDSP's transform is unscaled in both directions; N is the length actually transformed
                var factor = normalization.factor(count: countI, inverse: Self.inverse)
                if factor != 1.0 {
                    vDSP_vsmulD(realOutputArray, 1, &factor, &realOutputArray, 1, count)
                    vDSP_vsmulD(imagOutputArray, 1, &factor, &imagOutputArray, 1, count)
                }
            }
            else {
                realOutputArray = []
                imagOutputArray = []
            }

            //Real input is treated as complex with zero imaginary part and the full (mirrored) spectrum is returned,
            //matching Android, so real and complex FFTs of the same length behave identically
        }

        if let realOutput = realOutput {
            switch realOutput {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(realOutputArray)
            }
        }
        
        if let imagOutput = imagOutput {
            switch imagOutput {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(imagOutputArray)
            }
        }
    }

    //The exact transform of the first `count` samples as a direct O(N^2) sum over a twiddle table of N entries,
    //exp(sign*2*pi*i*k*n/N) = table[(k*n) mod N]. Fine for phone-sized buffers; Bluestein's algorithm would be the faster option.
    private func directTransform(count: Int) -> ([Double], [Double]) {
        let re = realInput.data
        let im = hasImagInBuffer ? imagInput!.data : nil
        let sign = Self.inverse ? 1.0 : -1.0
        let factor = normalization.factor(count: count, inverse: Self.inverse)

        var cosTable = [Double](repeating: 0.0, count: count)
        var sinTable = [Double](repeating: 0.0, count: count)
        for i in 0..<count {
            let angle = sign * 2.0 * Double.pi * Double(i) / Double(count)
            cosTable[i] = cos(angle)
            sinTable[i] = sin(angle)
        }

        var outRe = [Double](repeating: 0.0, count: count)
        var outIm = [Double](repeating: 0.0, count: count)
        for k in 0..<count {
            var sumRe = 0.0
            var sumIm = 0.0
            var index = 0
            for n in 0..<count {
                let c = cosTable[index]
                let s = sinTable[index]
                let xIm = im?[n] ?? 0.0
                sumRe += re[n] * c - xIm * s
                sumIm += re[n] * s + xIm * c
                index += k
                if index >= count {
                    index -= count
                }
            }
            outRe[k] = factor * sumRe
            outIm[k] = factor * sumIm
        }
        return (outRe, outIm)
    }
}

final class IFFTAnalysis: FFTAnalysis {
    override class var inverse: Bool { return true }
}

final class DFTAnalysis: FFTAnalysis {
    override class var exact: Bool { return true }
}

final class IDFTAnalysis: FFTAnalysis {
    override class var inverse: Bool { return true }
    override class var exact: Bool { return true }
}
