//
//  AutocorrelationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

final class AutocorrelationAnalysis: ExperimentAnalysisModule {
    private var minXIn: ExperimentAnalysisDataIO?
    private var maxXIn: ExperimentAnalysisDataIO?
    
    private var xIn: DataBuffer?
    private var yIn: DataBuffer!
    
    private var xOut: ExperimentAnalysisDataIO?
    private var yOut: ExperimentAnalysisDataIO?
    
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: AttributeContainer) throws {
        for input in inputs {
            if input.asString == "x" {
                switch input {
                case .buffer(buffer: let buffer, usedAs: _, clear: _):
                    xIn = buffer
                case .value(value: _, usedAs: _):
                    break
                }
            }
            else if input.asString == "y" {
                switch input {
                case .buffer(buffer: let buffer, usedAs: _, clear: _):
                    yIn = buffer
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
        
        let y = yIn.toArray()
        var count = y.count
        
        var xValues: [Double] = []
        var yValues: [Double] = []
        
        if count > 0 {
            if let xIn = xIn {
                count = min(xIn.memoryCount, count);
            }
            
            var x: [Double]!
            
            if xOut != nil {
                if xIn != nil {
                    x = [Double](repeating: 0.0, count: count)
                    
                    let xRaw = xIn!.toArray()
                    
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
        
        beforeWrite()
        
        if let yOut = yOut {
            switch yOut {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(yValues)
                }
                else {
                    buffer.appendFromArray(yValues)
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
        
        if let xOut = xOut {
            switch xOut {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(xValues)
                }
                else {
                    buffer.appendFromArray(xValues)
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
    }
}
