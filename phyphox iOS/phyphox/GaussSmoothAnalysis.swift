//
//  GaussSmoothAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import Accelerate

final class GaussSmoothAnalysis: ExperimentAnalysisModule {
    var calcWidth: Int = 0
    var kernel: [Float] = []
    
    var sigma: Double = 0.0 {
        didSet {
            calcWidth = Int(round(sigma*3.0))
            
            kernel.removeAll()
            kernel.reserveCapacity(2*calcWidth+1)
            
            let a = Float(sigma * sqrt(2.0*M_PI))
            let b = calcWidth
            let c = Float(sigma*sigma)
            
            for i in 0...2*calcWidth {
                let d = powf(Float(i-b), 2.0)
                
                let value = expf(-d/(2.0*c))/a
                
                kernel.append(value)
            }
        }
    }
    
    override init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String : AnyObject]?) {
        defer {
            sigma = floatTypeFromXML(additionalAttributes, key: "sigma", defaultValue: 3.0)
        }
        super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        #if DEBUG_ANALYSIS
            debug_noteInputs(["sigma" : sigma, "calcWidth" : calcWidth, "kernel" : kernel])
        #endif
        
        var input = self.inputs.first!.buffer!.toArray().map { Float($0) }
        
        let count = input.count
        
        let outputData = UnsafeMutablePointer<Float>.alloc(count)
        
        var inImg = vImage_Buffer(data: &input, height: 1, width: vImagePixelCount(count), rowBytes: count*sizeof(Float))
        var outImg = vImage_Buffer(data: outputData, height: 1, width: vImagePixelCount(count), rowBytes: count*sizeof(Float))
        
        vImageConvolve_PlanarF(&inImg, &outImg, nil, 0, 0, kernel, 1, UInt32(kernel.count), Pixel_F(0.0), vImage_Flags(kvImageBackgroundColorFill))
        
        let result = Array(UnsafeBufferPointer(start: unsafeBitCast(outImg.data, UnsafeMutablePointer<Float>.self), count: count)).map { Double($0) }
        
        outputData.destroy()
        outputData.dealloc(count)
        
        #if DEBUG_ANALYSIS
            debug_noteOutputs(result)
        #endif
        
        for output in outputs {
            if output.clear {
                output.buffer!.replaceValues(result)
            }
            else {
                output.buffer!.appendFromArray(result)
            }
        }
    }
}
