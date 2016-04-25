//
//  MaxAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation
import Accelerate

final class MaxAnalysis: ExperimentAnalysisModule {
    private var xIn: DataBuffer?
    private var yIn: DataBuffer!
    
    private var maxOut: ExperimentAnalysisDataIO?
    private var positionOut: ExperimentAnalysisDataIO?
    
    override init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String : AnyObject]?) {
        for input in inputs {
            if input.asString == "x" {
                xIn = input.buffer
            }
            else if input.asString == "y" {
                yIn = input.buffer
            }
            else {
                print("Error: Invalid analysis input: \(input.asString)")
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
                print("Error: Invalid analysis output: \(output.asString)")
            }
        }
        
        super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        #if DEBUG_ANALYSIS
            if xIn != nil {
                debug_noteInputs(["valIn" : yIn, "posIn" : xIn])
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
        
        if positionOut == nil {
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
