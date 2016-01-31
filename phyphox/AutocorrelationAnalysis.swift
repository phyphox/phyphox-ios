//
//  AutocorrelationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class AutocorrelationAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        var mint: Double = -Double.infinity
        var maxt: Double = Double.infinity
        
        //TODO: Nur ein x oder mehrere (in wiki steht mehrere)?
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
        
        var xOut: DataBuffer?
        var yOut: DataBuffer!
        
        for output in outputs {
            if output.asString == "x" {
                xOut = output.buffer!
            }
            else if output.asString == "y" {
                yOut = output.buffer!
            }
            else {
                print("Error: Invalid analysis output: \(output.asString)")
            }
        }
        
        //Get arrays for random access
        var y = yIn.toArray()
        var count = y.count
        
        if xIn != nil {
            count = min(xIn!.count, count);
        }
        
        var x = [Double](count: count, repeatedValue: 0.0) //Relative x (the displacement in the autocorrelation). This has to be filled from input2 or manually with 1,2,3...

        if xIn != nil {
            var xraw = xIn!.toArray()
            
            for (var i = 0; i < count; i++) {
                if (i < count) {
                    x[i] = xraw[i]-xraw[0]; //There is still input left. Use it and calculate the relative x
                }
                else {
                    x[i] = xraw[count - 1]-xraw[0]; //No input left. This probably leads to wrong results, but let's use the last value
                }
            }
        }
        else {
            //There is no input2. Let's fill it with 0,1,2,3,4....
            for (var i = 0; i < count; i++) {
                x[i] = Double(i);
            }
        }
        
        var xMax: Double? = nil
        var xMin: Double? = nil
        
        var yMax: Double? = nil
        var yMin: Double? = nil
        
        var xValues: [Double]? = (xOut != nil ? [] : nil)
        var yValues: [Double] = []
        
        //The actual calculation
        for (var i = 0; i < count; i++) { //Displacement i for each value of input1
            let xVal = x[i]
            
            if (xVal < mint || xVal > maxt) { //Skip this, if it should be filtered
                continue;
            }
            
            var sum = 0.0
            
            for (var j = 0; j < count-i; j++) { //For each value of input1 minus the current displacement
                sum += y[j]*y[j+i]; //Product of normal and displaced data
            }
            
            sum /= Double(count-i); //Normalize to the number of values at this displacement
            
            if xValues != nil {
                if xMax == nil || xVal > xMax {
                    xMax = xVal
                }
                
                if xMin == nil || xVal < xMin {
                    xMin = xVal
                }
            }
            
            if yMax == nil || sum > yMax {
                yMax = sum
            }
            
            if yMin == nil || sum < yMin {
                yMin = sum
            }
            
            //Append y output to output1 and x to output2 (if used)
            yValues.append(sum)
            
            if xValues != nil {
                xValues!.append(xVal)
            }
        }
        
        yOut.replaceValues(yValues, max: yMax, min: yMin)
        
        if xOut != nil {
            xOut!.replaceValues(xValues!, max: xMax, min: xMin)
        }
    }
}
