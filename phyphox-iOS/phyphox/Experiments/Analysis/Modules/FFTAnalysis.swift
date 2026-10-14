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
//every other length (fft-non-power-of-two-input, permanent); dft/idft are the exact transform for any length, on vDSP where
//it supports the length and via Bluestein's algorithm elsewhere, so both are O(N log N).
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
    //Exact for any length instead of vDSP's padded f*2^n lengths
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
        else {
            //Real input is treated as complex with zero imaginary part and the full (mirrored) spectrum is returned,
            //matching Android, so real and complex FFTs of the same length behave identically.
            //dft/idft are exact on vDSP at its own lengths and via Bluestein's algorithm at every other length; fft/ifft zero-pad
            let count = Self.exact ? bufferCount : nextFFTSize(bufferCount)
            let re = Self.resized(realInput.data, to: count)
            let im = Self.resized(imagInput?.data ?? [], to: count)
            let result = Self.vDSPTransform(re, im, inverse: Self.inverse) ?? (Self.exact ? Self.bluesteinTransform(re, im, inverse: Self.inverse) : ([], []))
            //vDSP's transform is unscaled in both directions; N is the length actually transformed
            let factor = normalization.factor(count: count, inverse: Self.inverse)
            realOutputArray = Self.scaled(result.re, by: factor)
            imagOutputArray = Self.scaled(result.im, by: factor)
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

    private static func resized(_ array: [Double], to count: Int) -> [Double] {
        return array.count >= count ? Array(array.prefix(count)) : array + [Double](repeating: 0.0, count: count - array.count)
    }

    private static func scaled(_ array: [Double], by factor: Double) -> [Double] {
        return factor == 1.0 ? array : vDSP.multiply(factor, array)
    }

    //Unscaled transform at the input's own length, nil if vDSP does not support that length
    private static func vDSPTransform(_ re: [Double], _ im: [Double], inverse: Bool) -> (re: [Double], im: [Double])? {
        //For now we recreate the DFT setup each time as it fixes some crashes.
        //Jonas noted before, that to fast calling of the DFT leads to crashes when reusing the setup, but I (Sebastian) was not able to reproduce this
        //Instead, I found that destroying the setup in deinit can lead to a crash as this is not thread safe and even if it was, the destruction might occur inbetween seting up the setup and actually executing the DFT
        //I would suggest reusing the setup for performance but make deinit thread safe, so it can only be called when analysis has been completed. However, for now the performance seems to be sufficient and memory allocation is no bottleneck whatsoever. So, let's stick to the clumsy, yet stable method for now.
        //vDSP documents a minimum length of 8 but accepts 1, 2 and 4 (iOS 26.5)
        guard let setup = vDSP_DFT_zop_CreateSetupD(nil, vDSP_Length(re.count), inverse ? .INVERSE : .FORWARD) else {
            return nil
        }
        defer { vDSP_DFT_DestroySetupD(setup) }
        var outRe = [Double](repeating: 0.0, count: re.count)
        var outIm = outRe
        vDSP_DFT_ExecuteD(setup, re, im, &outRe, &outIm)
        return (outRe, outIm)
    }

    //Bluestein's algorithm: the unscaled transform of any length N as a circular convolution with the chirp
    //w_k = exp(sign*i*pi*k^2/N), using 2kn = k^2 + n^2 - (k-n)^2, computed by vDSP at a supported length M >= 2N-1
    private static func bluesteinTransform(_ re: [Double], _ im: [Double], inverse: Bool) -> (re: [Double], im: [Double]) {
        let n = re.count
        let m = nextFFTSize(max(2*n - 1, 8)) //8 is vDSP's documented minimum
        let sign = inverse ? 1.0 : -1.0

        var wRe = [Double](repeating: 0.0, count: n)
        var wIm = [Double](repeating: 0.0, count: n)
        for k in 0..<n {
            let angle = sign * Double.pi * Double((k*k) % (2*n)) / Double(n) //k^2 mod 2N keeps the angle precise
            wRe[k] = cos(angle)
            wIm[k] = sin(angle)
        }

        //a = x*w, b = conj(w) placed symmetrically around index 0 of the circular buffer
        var aRe = [Double](repeating: 0.0, count: m)
        var aIm = aRe
        var bRe = aRe
        var bIm = aRe
        for k in 0..<n {
            aRe[k] = re[k] * wRe[k] - im[k] * wIm[k]
            aIm[k] = re[k] * wIm[k] + im[k] * wRe[k]
            bRe[k] = wRe[k]
            bIm[k] = -wIm[k]
            if k > 0 {
                bRe[m-k] = wRe[k]
                bIm[m-k] = -wIm[k]
            }
        }

        guard let a = vDSPTransform(aRe, aIm, inverse: false), let b = vDSPTransform(bRe, bIm, inverse: false) else {
            return ([], [])
        }
        for i in 0..<m {
            aRe[i] = a.re[i] * b.re[i] - a.im[i] * b.im[i]
            aIm[i] = a.re[i] * b.im[i] + a.im[i] * b.re[i]
        }
        guard let conv = vDSPTransform(aRe, aIm, inverse: true) else {
            return ([], [])
        }

        //X_k = w_k * conv_k, with 1/M undoing the unscaled inverse transform
        var outRe = [Double](repeating: 0.0, count: n)
        var outIm = [Double](repeating: 0.0, count: n)
        let scale = 1.0 / Double(m)
        for k in 0..<n {
            outRe[k] = scale * (wRe[k] * conv.re[k] - wIm[k] * conv.im[k])
            outIm[k] = scale * (wRe[k] * conv.im[k] + wIm[k] * conv.re[k])
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
