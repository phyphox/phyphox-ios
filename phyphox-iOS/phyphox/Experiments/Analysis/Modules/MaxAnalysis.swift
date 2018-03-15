//
//  MaxAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

final class MaxAnalysis: ExperimentAnalysisModule {
    private var xIn: DataBuffer?
    private var yIn: DataBuffer!
    private var thresholdIn: ExperimentAnalysisDataIO?
    
    private var maxOut: ExperimentAnalysisDataIO?
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
            if output.asString == "max" {
                maxOut = output
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
            if maxOut != nil {
                if maxOut!.clear {
                    maxOut!.buffer!.replaceValues([])
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
            var max = 0.0
            
            vDSP_maxvD(inArray, 1, &max, vDSP_Length(inArray.count))
            
            if maxOut != nil {
                if maxOut!.clear {
                    maxOut!.buffer!.replaceValues([max])
                }
                else {
                    maxOut!.buffer!.append(max)
                }
            }
            
            #if DEBUG_ANALYSIS
                debug_noteOutputs(max)
            #endif
            
        }
        else if multiple {
            var max = [Double]()
            var x = [Double]()
            let threshold = thresholdIn?.getSingleValue() ?? 0.0
            
            var thisMax = -Double.infinity
            var thisX = -Double.infinity
            for (i, v) in inArray.enumerated() {
                if v < threshold {
                    if (thisX.isFinite) {
                        max.append(thisMax)
                        x.append(thisX)
                        thisMax = -Double.infinity
                        thisX = -Double.infinity
                    }
                } else if v > thisMax {
                    thisMax = v
                    thisX = xIn?.objectAtIndex(i) ?? Double(i)
                }
            }
            
            if maxOut != nil {
                if maxOut!.clear {
                    maxOut!.buffer!.replaceValues(max)
                }
                else {
                    maxOut!.buffer!.appendFromArray(max)
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
            var max = -Double.infinity
            var index: vDSP_Length = 0
            
            vDSP_maxviD(inArray, 1, &max, &index, vDSP_Length(inArray.count))
            
            let x: Double
            
            if xIn != nil {
                guard let n = xIn!.objectAtIndex(Int(index)) else {
                    print("[Max analysis]: Index \(Int(index)) is out of bounds of x value array \(xIn!)")
                    return
                }
                
                x = n
            }
            else {
                x = Double(index)
            }
            
            if maxOut != nil {
                if maxOut!.clear {
                    maxOut!.buffer!.replaceValues([max])
                }
                else {
                    maxOut!.buffer!.append(max)
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
                debug_noteOutputs(["max" : max, "pos" : x])
            #endif
            
        }
    }
}
