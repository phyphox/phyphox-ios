//
//  AutocorrelationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import Accelerate

final class AutocorrelationAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        var mint: Double = -Double.infinity
        var maxt: Double = Double.infinity
        
        var xIn: DataBuffer?
        var yIn: DataBuffer!
        
        for input in inputs {
            if input.asString == "x" {
                xIn = input.buffer!
            }
            else if input.asString == "y" {
                yIn = input.buffer!
            }
            else if input.asString == "minX" {
                if let v = input.getSingleValue() {
                    mint = v
                }
                else {
                    return
                }
            }
            else if input.asString == "maxX" {
                if let v = input.getSingleValue() {
                    maxt = v
                }
                else {
                    return
                }
            }
            else {
                print("Error: Invalid analysis input: \(input.asString)")
            }
        }
        
        var xOut: ExperimentAnalysisDataIO?
        var yOut: ExperimentAnalysisDataIO?
        
        for output in outputs {
            if output.asString == "x" {
                xOut = output
            }
            else if output.asString == "y" {
                yOut = output
            }
            else {
                print("Error: Invalid analysis output: \(output.asString)")
            }
        }
        
        var y = yIn.toArray()
        var count = y.count
        
        var xValues: [Double]? = (xOut != nil ? [] : nil)
        var yValues: [Double] = []
        
        if count > 0 {
            if xIn != nil {
                count = min(xIn!.count, count);
            }
            
            var x: [Double]?
            
            if xOut != nil {
                if xIn != nil {
                    x = [Double](count: count, repeatedValue: 0.0)
                    
                    let xRaw = xIn!.toArray()
                    
                    let first = xRaw.first
                    
                    if first == nil {
                        return
                    }
                    
                    if first! == 0.0 {
                        x = xRaw
                    }
                    else {
                        vDSP_vsaddD(xRaw, 1, [-first!], &x!, 1, vDSP_Length(count))
                    }
                }
                else {
                    x = [Double](count: count, repeatedValue: 0.0)
                    
                    vDSP_vrampD([0.0], [1.0], &x!, 1, vDSP_Length(count))
                }
            }
            /*
             var index = 0
             var minimizedY = y
             
             let minimizedX = x.filter { (d) -> Bool in
             if d < mint || d > maxt {
             minimizedY.removeAtIndex(index)
             return false
             }
             
             index += 1
             
             return true
             }
             
             func xcorr(x: [Double]) -> [Double] {
             let resultSize = 2*x.count - 1
             var result = [Double](count: resultSize, repeatedValue: 0)
             let xPad = Repeat(count: x.count-1, repeatedValue: Double(0.0))
             let xPadded = xPad + x + xPad
             vDSP_convD(xPadded, 1, x, 1, &result, 1, vDSP_Length(resultSize), vDSP_Length(x.count))
             
             return result
             }
             //
             let corrY = xcorr(minimizedY)
             
             var normalizeVector = [Double](count: count, repeatedValue: 0.0)
             
             vDSP_vrampD([Double(count)], [-1.0], &normalizeVector, 1, vDSP_Length(count))
             
             var normalizedY = normalizeVector
             
             vDSP_vdivD(corrY, 1, normalizeVector, 1, &normalizedY, 1, vDSP_Length(count))
             */
            
            //        yOut.replaceValues(finalY)
            //
            //        if xOut != nil {
            //            xOut!.replaceValues(finalX)
            //        }
            
            
            
            //The actual calculation
            for i in 0 ..< count { //Displacement i for each value of input1
                if x != nil {
                    let xVal = x![i]
                    
                    if (xVal < mint || xVal > maxt) { //Skip this, if it should be filtered
                        continue
                    }
                    
                    if xValues != nil {
                        xValues!.append(xVal)
                    }
                }
                
                var sum = 0.0
                
                for j in 0 ..< count-i { //For each value of input1 minus the current displacement
                    sum += y[j]*y[j+i]; //Product of normal and displaced data
                }
                
                sum /= Double(count-i); //Normalize to the number of values at this displacement
                
                
                yValues.append(sum)
            }
        }
        
        if yOut != nil {
            if yOut!.clear {
                yOut!.buffer!.replaceValues(yValues)
            }
            else {
                yOut!.buffer!.appendFromArray(yValues)
            }
        }
        
        if xOut != nil {
            if xOut!.clear {
                xOut!.buffer!.replaceValues(xValues!)
            }
            else {
                xOut!.buffer!.appendFromArray(xValues!)
            }
        }
    }
}
