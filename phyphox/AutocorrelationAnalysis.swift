//
//  AutocorrelationAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import Surge

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
        
        var x = [Double]() //Relative x (the displacement in the autocorrelation). This has to be filled from input2 or manually with 1,2,3...

        if xIn != nil {
            var xraw = xIn!.toArray()
            
            let first = xraw.first
            
            for i in 0 ..< count {
                x.append(xraw[i]-first!) //Calculate the relative x
            }
        }
        else {
            //There is no input2. Let's fill it with 0,1,2,3,4....
            for i in 0 ..< count {
                x.append(Double(i))
            }
        }
        
//        var index = 0
//        
//        var minimizedY = y
//        
//        let finalX = x.filter { (d) -> Bool in
//            if d < mint || d > maxt {
//                minimizedY.removeAtIndex(index)
//                return false
//            }
//            
//            index += 1
//            
//            return true
//        }
//        
//        let finalY = Surge.xcorr(minimizedY)
//        yOut.replaceValues(finalY)
//        
//        if xOut != nil {
//            xOut!.replaceValues(finalX)
//        }
        
        var xValues: [Double]? = (xOut != nil ? [] : nil)
        var yValues: [Double] = []
        
        //The actual calculation
        for i in 0 ..< count { //Displacement i for each value of input1
            let xVal = x[i]
            
            if (xVal < mint || xVal > maxt) { //Skip this, if it should be filtered
                continue;
            }
            
            var sum = 0.0
            
            for j in 0 ..< count-i { //For each value of input1 minus the current displacement
                sum += y[j]*y[j+i]; //Product of normal and displaced data
            }
            
            sum /= Double(count-i); //Normalize to the number of values at this displacement
            
            //Append y output to output1 and x to output2 (if used)
            yValues.append(sum)
            
            if xValues != nil {
                xValues!.append(xVal)
            }
        }
        
        yOut.replaceValues(yValues)
        
        if xOut != nil {
            xOut!.replaceValues(xValues!)
        }
    }
}
