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
            debug_noteInputs(["sigma" : sigma, "calcWidth" : calcWidth, "gauss" : gauss])
        #endif
        
        var final: [Double]!
        
        measure("a") { 
            var input = self.inputs.first!.buffer!.toArray().map { Float($0) }
            
            let count = input.count
            
            let outputData = UnsafeMutablePointer<Float>.alloc(count)
            
            var inImg = vImage_Buffer(data: &input, height: 1, width: vImagePixelCount(count), rowBytes: count*sizeof(Float))
            var outImg = vImage_Buffer(data: outputData, height: 1, width: vImagePixelCount(count), rowBytes: count*sizeof(Float))
            
            vImageConvolve_PlanarF(&inImg, &outImg, nil, 0, 0, self.kernel, 1, UInt32(self.kernel.count), Pixel_F(0.0), vImage_Flags(kvImageBackgroundColorFill))
            
            final = Array(UnsafeBufferPointer(start: unsafeBitCast(outImg.data, UnsafeMutablePointer<Float>.self), count: count)).map { Double($0) }
            
            outputData.destroy()
            outputData.dealloc(count)
        }

        
        var append: [Double] = []
        
        measure("b") { 
            var y = self.inputs.first!.buffer!.toArray()
            
            for i in 0..<y.count {
                var sum = 0.0
                
                for j in -self.calcWidth...self.calcWidth {
                    let k = i+j
                    if (k >= 0 && k < y.count) {
                        sum += Double(self.kernel[j+self.calcWidth])*y[k]
                    }
                }
                
                append.append(sum)
            }
        }
        
        var d = Double.infinity
        
        for i in 0..<append.count {
            let a = append[i]
            let b = final[i]
            
            let delta = abs(a-b)
            
            if delta < d {
                d = delta
            }
        }
        
        print("Gauss results max delta: \(d)")
        
        #if DEBUG_ANALYSIS
            debug_noteOutputs(final)
        #endif
        
        let outBuffer = outputs.first!.buffer!
        
        outBuffer.replaceValues(final)

    }
}
