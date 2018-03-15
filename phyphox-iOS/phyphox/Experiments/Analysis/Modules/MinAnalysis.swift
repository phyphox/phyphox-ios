//
//  MinAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 02.05.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//


import Foundation
import Accelerate

final class MinAnalysis: ExperimentAnalysisModule {
    private var xIn: DataBuffer?
    private var yIn: DataBuffer!
    private var thresholdIn: ExperimentAnalysisDataIO?
    
    private var minOut: ExperimentAnalysisDataIO?
    private var positionOut: ExperimentAnalysisDataIO?
    
    private var multiple: Bool
    
    override init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String : AnyObject]?) throws {
        
        multiple = boolFromXML(additionalAttributes, key: "multiple", defaultValue: false)
        
        for input in inputs {
            if input.asString == "x" {
                xIn = input.buffer
            }
            else if input.asString == "y" {
                yIn = input.buffer
            }
            else if input.asString == "threshold" {
                thresholdIn = input
            }
            else {
                print("Error: Invalid analysis input: \(String(describing: input.asString))")
            }
        }
        
        for output in outputs {
            if output.asString == "min" {
                minOut = output
            }
            else if output.asString == "position" {
                positionOut = output
            }
            else {
                print("Error: Invalid analysis output: \(String(describing: output.asString))")
            }
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        #if DEBUG_ANALYSIS
            if xIn != nil && thresholdIn != nil {
                debug_noteInputs(["valIn" : yIn, "posIn" : xIn, "thresholdIn" : thresholdIn])
            }
            else if xIn != nil {
                debug_noteInputs(["valIn" : yIn, "posIn" : xIn])
            }
            else if thresholdIn != nil {
                debug_noteInputs(["valIn" : yIn, "thresholdIn" : thresholdIn])
            }
            else {
                debug_noteInputs(["valIn" : yIn])
            }
        #endif
        
        let inArray = yIn.toArray()
        
        if inArray.count == 0 {
            if minOut != nil {
                if minOut!.clear {
                    minOut!.buffer!.replaceValues([])
                }
            }
            
            if positionOut != nil {
                if positionOut!.clear {
                    positionOut!.buffer!.replaceValues([])
                }
            }
            
            return
        }
        
        if positionOut == nil && !multiple {
            var min = 0.0
            
            vDSP_minvD(inArray, 1, &min, vDSP_Length(inArray.count))
            
            if minOut != nil {
                if minOut!.clear {
                    minOut!.buffer!.replaceValues([min])
                }
                else {
                    minOut!.buffer!.append(min)
                }
            }
            
            #if DEBUG_ANALYSIS
                debug_noteOutputs(min)
            #endif
            
        }
        else if multiple {
            var min = [Double]()
            var x = [Double]()
            let threshold = thresholdIn?.getSingleValue() ?? 0.0
            
            var thisMin = Double.infinity
            var thisX = -Double.infinity
            for (i, v) in inArray.enumerated() {
                if v > threshold {
                    if (thisX.isFinite) {
                        min.append(thisMin)
                        x.append(thisX)
                        thisMin = Double.infinity
                        thisX = -Double.infinity
                    }
                } else if v < thisMin {
                    thisMin = v
                    thisX = xIn?.objectAtIndex(i) ?? Double(i)
                }
            }
            
            if minOut != nil {
                if minOut!.clear {
                    minOut!.buffer!.replaceValues(min)
                }
                else {
                    minOut!.buffer!.appendFromArray(min)
                }
            }
            
            if positionOut != nil {
                if positionOut!.clear {
                    positionOut!.buffer!.replaceValues(x)
                }
                else {
                    positionOut!.buffer!.appendFromArray(x)
                }
            }
        }
        else {
            var min = -Double.infinity
            var index: vDSP_Length = 0
            
            vDSP_minviD(inArray, 1, &min, &index, vDSP_Length(inArray.count))
            
            let x: Double
            
            if xIn != nil {
                guard let n = xIn!.objectAtIndex(Int(index)) else {
                    print("[Min analysis]: Index \(Int(index)) is out of bounds of x value array \(xIn!)")
                    return
                }
                
                x = n
            }
            else {
                x = Double(index)
            }
            
            if minOut != nil {
                if minOut!.clear {
                    minOut!.buffer!.replaceValues([min])
                }
                else {
                    minOut!.buffer!.append(min)
                }
            }
            
            if positionOut != nil {
                if positionOut!.clear {
                    positionOut!.buffer!.replaceValues([x])
                }
                else {
                    positionOut!.buffer!.append(x)
                }
            }
            
            #if DEBUG_ANALYSIS
                debug_noteOutputs(["min" : min, "pos" : x])
            #endif
            
        }
    }
}
