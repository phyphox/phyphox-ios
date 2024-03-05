//
//  AutocorrelationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

final class AutocorrelationAnalysis: AutoClearingExperimentAnalysisModule {
    private var minXIn: ExperimentAnalysisDataInput?
    private var maxXIn: ExperimentAnalysisDataInput?
    
    private var xIn: MutableDoubleArray?
    private var yIn: MutableDoubleArray!
    
    private var xOut: ExperimentAnalysisDataOutput?
    private var yOut: ExperimentAnalysisDataOutput?
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        for input in inputs {
            if input.asString == "x" {
                switch input {
                case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                    xIn = data
                case .value(value: _, usedAs: _):
                    break
                }
            }
            else if input.asString == "y" {
                switch input {
                case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                    yIn = data
                case .value(value: _, usedAs: _):
                    break
                }
            }
            else if input.asString == "minX" {
                minXIn = input
            }
            else if input.asString == "maxX" {
                maxXIn = input
            }
            else {
                print("Error: Invalid analysis input: \(String(describing: input.asString))")
            }
        }
        
        for output in outputs {
            if output.asString == "x" {
                xOut = output
            }
            else if output.asString == "y" {
                yOut = output
            }
            else {
                print("Error: Invalid analysis output: \(String(describing: output.asString))")
            }
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        var minX: Double = -Double.infinity
        var maxX: Double = Double.infinity
        
        var needsFiltering = false
        
        if let m = minXIn?.getSingleValue() {
            minX = m
            needsFiltering = true
        }
        
        if let m = maxXIn?.getSingleValue() {
            maxX = m
            needsFiltering = true
        }
        
        let y = yIn.data
        var count = y.count
        
        var xValues: [Double] = []
        var yValues: [Double] = []
        
        if count > 0 {
            if let xIn = xIn {
                count = min(xIn.data.count, count);
            }
            
            var x: [Double]!
            
            if xOut != nil {
                if xIn != nil {
                    x = [Double](repeating: 0.0, count: count)
                    
                    let xRaw = xIn!.data
                    
                    let first = xRaw.first
                    
                    if first == nil {
                        return
                    }
                    
                    if first! == 0.0 {
                        x = xRaw
                    }
                    else {
                        x!.withUnsafeMutableBufferPointer { buffer in
                            guard let pointer = buffer.baseAddress else { return }

                            vDSP_vsaddD(xRaw, 1, [-first!], pointer, 1, vDSP_Length(count))
                        }
                    }
                }
                else {
                    x = [Double](repeating: 0.0, count: count)

                    x!.withUnsafeMutableBufferPointer { buffer in
                        guard let pointer = buffer.baseAddress else { return }

                        vDSP_vrampD([0.0], [1.0], pointer, 1, vDSP_Length(count))
                    }
                }
            }
            
            /*
             A := [a0, ... , an]
             F := [a0, ... , an]
             
             (wanted behaviour)
             for (n = 0; n < N; ++n)
                C[n] = sum(A[n+p] * F[p], 0 <= p < N-n);
             
             <=>
             
             P := N
             A := [a0, ... , an, 0, ... , 0]
             F := [a0, ... , an]
             
             (vDSP_conv)
             for (n = 0; n < N; ++n)
                C[n] = sum(A[n+p] * F[p], 0 <= p < P);
             */
            
            var normalizeVector = [Double](repeating: 0.0, count: count)
            
            let paddedY = y + normalizeVector
            
            var corrY = y
            
            vDSP_convD(paddedY, 1, paddedY, 1, &corrY, 1, vDSP_Length(count), vDSP_Length(count))
            
            
            //Normalize
            vDSP_vrampD([Double(count)], [-1.0], &normalizeVector, 1, vDSP_Length(count))
            
            var normalizedY = normalizeVector
            
            vDSP_vdivD(normalizeVector, 1, corrY, 1, &normalizedY, 1, vDSP_Length(count))
            
            
            var minimizedY = normalizedY
            
            let minimizedX: [Double]
            
            if needsFiltering {
                var index = 0
                
                minimizedX = x.filter { d -> Bool in
                    if d < minX || d > maxX {
                        if index < minimizedY.count {
                            minimizedY.remove(at: index)
                        }
                        return false
                    }
                    
                    index += 1
                    
                    return true
                }
            }
            else {
                minimizedX = x
            }
            
            xValues = minimizedX
            yValues = minimizedY
        }
                
        if let yOut = yOut {
            switch yOut {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(yValues)
            }
        }
        
        if let xOut = xOut {
            switch xOut {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(xValues)
            }
        }
    }
}
