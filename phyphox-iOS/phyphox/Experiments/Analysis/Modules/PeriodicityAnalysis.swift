//
//  PeriodicityAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 02.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
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
    private var xInput: DataBuffer!
    private var yInput: DataBuffer!
    private var dxInput: ExperimentAnalysisDataIO!
    private var overlapInput: ExperimentAnalysisDataIO?
    private var minInput: ExperimentAnalysisDataIO?
    private var maxInput: ExperimentAnalysisDataIO?
    
    private var timeOutput: ExperimentAnalysisDataIO?
    private var periodOutput: ExperimentAnalysisDataIO?
    
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: AttributeContainer) throws {
        for input in inputs {
            if input.asString == "x" {
                switch input {
                case .buffer(buffer: let buffer, usedAs: _, clear: _):
                    xInput = buffer
                case .value(value: _, usedAs: _):
                    throw SerializationError.genericError(message: "x input can only be a buffer")
                }
            }
            else if input.asString == "y" {
                switch input {
                case .buffer(buffer: let buffer, usedAs: _, clear: _):
                    yInput = buffer
                case .value(value: _, usedAs: _):
                    throw SerializationError.genericError(message: "y input can only be a buffer")
                }
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
        let x: [Double] = xInput.toArray()
        let y: [Double] = yInput.toArray()

        let n = y.count
        
        var dx = dxInput.getSingleValueAsInt() ?? 1
        if dx <= 0 {
            dx = 1
        }
        
        var overlap = 0
        
        if let o = overlapInput?.getSingleValueAsInt() {
            overlap = o
        }
        
        var minPeriod = 0
        var userSelectedRange = false
        
        if let m = minInput?.getSingleValueAsInt() {
            minPeriod = m
            userSelectedRange = true
        }
        
        var maxPeriod = Int.max
        
        if let m = maxInput?.getSingleValueAsInt() {
            maxPeriod = m
            userSelectedRange = true
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
                
                if !userSelectedRange && firstNegative < 0 {
                    if (sum < 0) { //So, this is the first negative one... We can now skip ahead to 3 times this position and work more precisely from there.
                        firstNegative = i
                        i = 3*firstNegative+1
                        step = 1
                    }
                }
                else if !userSelectedRange && i > 5 * firstNegative { //We have passed the first period. Further maxima can only be found on the next period and we are not interested in this...
                    break
                }
                else if userSelectedRange || i > 3 * firstNegative {
                    if sum > maxValue {
                        maxValue = sum
                        maxPosition = i
                        maxValueLeft = lastSum
                        maxValueRight = -Double.infinity
                    }
                    else if i == maxPosition + 1 {
                        maxValueRight = sum
                    }
                }
                
                lastSum = sum
                
                i += step
            }
            
            var xMax = Double.nan
            
            if maxPosition > 0 && maxValue > 0 && maxValueLeft > 0 && maxValueRight > 0 {
                let dy = 0.5 * (maxValueRight - maxValueLeft)
                let d2y = 2*maxValue - maxValueLeft - maxValueRight
                let m = dy / d2y
                xMax = x[x1+maxPosition] + 0.5*m*(x[x1+maxPosition+1] - x[x1+maxPosition-1]) - x[x1]
            }
            
            timeOut.append(x[x1])
            periodOut.append(xMax)
        }
        
        beforeWrite()

        if let timeOutput = timeOutput {
            switch timeOutput {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(timeOut)
                }
                else {
                    buffer.appendFromArray(timeOut)
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
        
        if let periodOutput = periodOutput {
            switch periodOutput {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(periodOut)
                }
                else {
                    buffer.appendFromArray(periodOut)
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
    }
}
