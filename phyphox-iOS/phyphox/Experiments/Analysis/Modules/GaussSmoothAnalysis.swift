//
//  GaussSmoothAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

final class GaussSmoothAnalysis: ExperimentAnalysisModule {
    private var calcWidth: Int = 0
    private var kernel: [Float] = []

    private let inputBuffer: DataBuffer

    private var sigma: Double = 0.0 {
        didSet {
            calcWidth = Int(round(sigma*3.0))
            
            kernel.removeAll()
            kernel.reserveCapacity(2*calcWidth+1)
            
            let c = Float(sigma*sigma)
            var sum = Float(0)
            
            for i in -calcWidth...calcWidth {
                let d = Float(i*i)
                
                let value = expf(-d/(2.0*c))
                sum += value
                kernel.append(value)
            }
            for i in 0..<kernel.count {
                kernel[i] /= sum
            }
        }
    }
    
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: AttributeContainer) throws {
        let attributes = additionalAttributes.attributes(keyedBy: String.self)

        sigma = 1.0
        guard let firstInput = inputs.first else { throw SerializationError.genericError(message: "Input must be a buffer") }

        switch firstInput {
        case .buffer(buffer: let buffer, usedAs: _, clear: _):
            inputBuffer = buffer
        case .value(value: _, usedAs: _):
            throw SerializationError.genericError(message: "Input must be a buffer")
        }

        let sigmaValue = try attributes.optionalValue(for: "sigma") ?? 3.0

        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)

        defer {
            sigma = sigmaValue
        }
    }
    
    override func update() {
        #if DEBUG_ANALYSIS
            debug_noteInputs(["sigma" : sigma, "calcWidth" : calcWidth, "kernel" : kernel])
        #endif
        
        var input = inputBuffer.toArray().map { Float($0) }
        
        let count = input.count
        
        
        let outputData = UnsafeMutablePointer<Float>.allocate(capacity: count)

        let result = input.withUnsafeMutableBufferPointer{input -> [Double] in
            var inImg = vImage_Buffer(data: input.baseAddress!, height: 1, width: vImagePixelCount(count), rowBytes: count*MemoryLayout<Float>.size)
            var outImg = vImage_Buffer(data: outputData, height: 1, width: vImagePixelCount(count), rowBytes: count*MemoryLayout<Float>.size)
            
            vImageConvolve_PlanarF(&inImg, &outImg, nil, 0, 0, kernel, 1, UInt32(kernel.count), Pixel_F(0.0), vImage_Flags(kvImageTruncateKernel))
            
            return Array(UnsafeBufferPointer(start: unsafeBitCast(outImg.data, to: UnsafeMutablePointer<Float>.self), count: count)).map(Double.init)
        }
        outputData.deinitialize(count: count)
        outputData.deallocate()

        

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
