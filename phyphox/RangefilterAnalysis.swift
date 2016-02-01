//
//  RangefilterAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class RangefilterAnalysis: ExperimentAnalysisModule {
    private final class Range: NSObject {
        var min: Double
        var max: Double
        
        func inBounds(value: Double) -> Bool {
            return min <= value && value <= max
        }
        
        init(min: Double, max: Double) {
            self.min = min
            self.max = max
        }
        
        override var description: String {
            get {
                return String(format: "Range <%p> (\(min), \(max))", self)
            }
        }
    }
    
    //TODO: TEST!!!
    
    override func update() {
        var iterators: [(Range, DataBuffer)] = []
        
        var currentIn: DataBuffer? = nil
        var currentMax: Double = Double.infinity
        var currentMin: Double = -Double.infinity
        
        for input in inputs {
            if input.asString == "min" {
                if let v = input.getSingleValue() {
                    currentMin = v
                }
                else {
                    return
                }
            }
            else if input.asString == "max" {
                if let v = input.getSingleValue() {
                    currentMax = v
                }
                else {
                    return
                }
            }
            else if let b = input.buffer { //in
                if currentIn != nil {
                    iterators.append((Range(min: currentMin, max: currentMax), currentIn!))
                }
                
                currentIn = b
                currentMax = Double.infinity
                currentMin = -Double.infinity
            }
        }
        
        if currentIn != nil {
            iterators.append((Range(min: currentMin, max: currentMax), currentIn!))
        }
        
        var max: Double? = nil
        var min: Double? = nil
        
        let delete = NSMutableIndexSet()
        
        var out = [[Double]](count: iterators.count, repeatedValue: [])
        
        var deleteCount = 0
        
        for (index, (range, buffer)) in iterators.enumerate() {
            for (i, value) in buffer.enumerate() {
                if delete.containsIndex(i) {
                    continue
                }
                
                if !range.inBounds(value) {
                    delete.addIndex(i)
                    
                    let delIdx = i-deleteCount
                    
                    for j in 0..<index {
                        if delIdx < out[j].count {
                            out[j].removeAtIndex(delIdx) //Remove values from previous buffers that passed.
                        }
                    }
                    
                    deleteCount++
                    
                    continue
                }
                
                if max == nil || value > max {
                    max = value
                }
                
                if min == nil || value < min {
                    min = value
                }
                
                out[index].append(value)
            }
        }
        
        for (i, output) in outputs.enumerate() {
            output.buffer!.replaceValues(out[i], max: max, min: min)
        }
    }
}
