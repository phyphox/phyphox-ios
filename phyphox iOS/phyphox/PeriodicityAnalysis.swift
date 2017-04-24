//
//  PeriodicityAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 02.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

final class PeriodicityAnalysis: ExperimentAnalysisModule {
    //Calculate the periodicity over time by doing autocorrelations on a series of subsets of the input data
    //input1 is x values
    //input2 is y values
    //input3 is step distance dx in samples
    //input4 is step overlap in samples (optional, default: 0)
    //input5 is the minimum period in samples (optional, default: 0)
    //input6 is the maximum period in samples (optional, default: +Inf)
    //input6 is the precision in samples (optional, default: 1)
    
    //output1 is the periodicity in units of input1
    fileprivate var xInput: ExperimentAnalysisDataIO!
    fileprivate var yInput: ExperimentAnalysisDataIO!
    fileprivate var dxInput: ExperimentAnalysisDataIO!
    fileprivate var overlapInput: ExperimentAnalysisDataIO?
    fileprivate var minInput: ExperimentAnalysisDataIO?
    fileprivate var maxInput: ExperimentAnalysisDataIO?
    
    fileprivate var timeOutput: ExperimentAnalysisDataIO?
    fileprivate var periodOutput: ExperimentAnalysisDataIO?
    
    override init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String : AnyObject]?) throws {
        for input in inputs {
            if input.asString == "x" {
                xInput = input
            }
            else if input.asString == "y" {
                yInput = input
            }
            else if input.asString == "dx" {
                dxInput = input
            }
            else if input.asString == "overlap" {
                overlapInput = input
            }
            else if input.asString == "min" {
                minInput = input
            }
            else if input.asString == "max" {
                maxInput = input
            }
            else {
                print("Error: Invalid analysis output: \(String(describing: input.asString))")
            }
        }
        
        for output in outputs {
            if output.asString == "time" {
                timeOutput = output
            }
            else if output.asString == "period" {
                periodOutput = output
            }
            else {
                print("Error: Invalid analysis output: \(String(describing: output.asString))")
            }
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        let x = xInput.buffer!.toArray()
        let y = yInput.buffer!.toArray()
        
        let n = y.count
        
        var dx = Int(dxInput.getSingleValue()!)
        if dx <= 0 {
            dx = 1
        }
        
        var overlap = 0
        
        if let o = overlapInput?.getSingleValue() {
            if o.isFinite {
                overlap = Int(o)
            }
        }
        
        var minPeriod = 0
        var userSelectedRange = false
        
        if let m = minInput?.getSingleValue() {
            if m.isFinite {
                minPeriod = Int(m)
                userSelectedRange = true
            }
        }
        
        var maxPeriod = Int.max
        
        if let m = maxInput?.getSingleValue() {
            if m.isFinite {
                maxPeriod = Int(m)
                userSelectedRange = true
            }
        }
        
        var timeOut = [Double]()
        var periodOut = [Double]()
        
        for stepX in stride(from: 0, through: n-dx, by: dx) {
            //Calculate actual autocorrelation range as it might be cut off at the edges
            let x1 = max(stepX-overlap, 0)
            
            let x2 = min(stepX+dx+overlap, n)
            
            if (maxPeriod > x2-x1) {
                maxPeriod = x2-x1
            }
            
            var firstNegative = -1
            var maxPosition = -1
            var maxValue = -Double.infinity
            var maxValueLeft = -Double.infinity
            var maxValueRight = -Double.infinity
            var lastSum = -Double.infinity
            
            var step = userSelectedRange ? 1 : 2
            
            var i = minPeriod
            
            while i < maxPeriod {
                var sum = 0.0
                
                for j in x1..<x2-i { //For each value of input1 minus the current displacement
                    sum += y[j] * y[j + i] //Product of normal and displaced data
                }
                
                sum /= Double(x2-x1-i) //Normalize to the number of values at this displacement
                
                if (!userSelectedRange && firstNegative < 0) {
                    if (sum < 0) { //So, this is the first negative one... We can now skip ahead to 3 times this position and work more precisely from there.
                        firstNegative = i
                        i = 3*firstNegative+1
                        step = 1
                    }
                }
                else if (!userSelectedRange && i > 5 * firstNegative) { //We have passed the first period. Further maxima can only be found on the next period and we are not interested in this...
                    break
                }
                else if (userSelectedRange || i > 3 * firstNegative) {
                    if (sum > maxValue) {
                        maxValue = sum
                        maxPosition = i
                        maxValueLeft = lastSum
                        maxValueRight = -Double.infinity
                    }
                    else if (i == maxPosition + 1) {
                        maxValueRight = sum
                    }
                }
                
                lastSum = sum
                
                i += step
            }
            
            var xMax = Double.nan
            
            if (maxPosition > 0 && maxValue > 0 && maxValueLeft > 0 && maxValueRight > 0) {
                let dy = 0.5 * (maxValueRight - maxValueLeft)
                let d2y = 2*maxValue - maxValueLeft - maxValueRight
                let m = dy / d2y
                xMax = x[x1+maxPosition] + 0.5*m*(x[x1+maxPosition+1] - x[x1+maxPosition-1]) - x[x1]
            }
            
            timeOut.append(x[x1])
            periodOut.append(xMax)
        }
        
        if timeOutput != nil {
            if timeOutput!.clear {
                timeOutput!.buffer!.replaceValues(timeOut)
            }
            else {
                timeOutput!.buffer!.appendFromArray(timeOut)
            }
        }
        
        if periodOutput != nil {
            if periodOutput!.clear {
                periodOutput!.buffer!.replaceValues(periodOut)
            }
            else {
                periodOutput!.buffer!.appendFromArray(periodOut)
            }
        }
    }
}
