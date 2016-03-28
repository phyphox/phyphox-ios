//
//  MaxAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import Surge

final class MaxAnalysis: ExperimentAnalysisModule {
    var xIn: DataBuffer?
    var yIn: DataBuffer!
    
    var maxOut: DataBuffer?
    var positionOut: DataBuffer?
    
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
                maxOut = output.buffer
            }
            else if output.asString == "position" {
                positionOut = output.buffer
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
        
        if positionOut == nil {
            let max = Surge.max(yIn.toArray())
            
            if maxOut != nil {
                maxOut!.append(max)
            }
            
            #if DEBUG_ANALYSIS
                debug_noteOutputs(max)
            #endif
            
        }
        else {
            let inArray = yIn.toArray()
            
            if inArray.count == 0 {
                return
            }
            
            var max = -Double.infinity
            var index: vDSP_Length = 0
            
            vDSP_maxviD(inArray, 1, &max, &index, vDSP_Length(inArray.count))
            
            let x = (xIn != nil ? xIn![Int(index)] : Double(index))
            
            if maxOut != nil {
                maxOut!.append(max)
            }
            
            if positionOut != nil {
                positionOut!.append(x)
            }
            
            #if DEBUG_ANALYSIS
                debug_noteOutputs(["max" : max, "pos" : x!])
            #endif
            
        }
    }
}
