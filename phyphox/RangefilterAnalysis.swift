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
        
        override var description: String { get {
            return String(format: "Range <%p> (\(min), \(max))", self)
            }
        }
    }
    
    //TODO: Ich weiß nicht ob es richtig implementiert ist, peile die Dokumentation vom rangefilter nicht
    
    override func update() {
        var iterators: [Range: DataBuffer] = [:]
        
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
                    iterators[Range(min: currentMin, max: currentMax)] = currentIn!
                }
                
                currentIn = b
            }
        }
        
        if currentIn != nil {
            iterators[Range(min: currentMin, max: currentMax)] = currentIn!
        }
        
        var max: Double? = nil
        var min: Double? = nil
        
        var data: [Double] = []
        
        for (range, buffer) in iterators {
            for value in buffer {
                if !range.inBounds(value) {
                    break //Out of bounds, skip these values
                }
                
                if max == nil || value > max {
                    max = value
                }
                
                if min == nil || value < min {
                    min = value
                }
                
                data.append(value)
            }
        }
        
        for output in outputs {
            output.buffer!.replaceValues(data, max: max, min: min)
        }
    }
}
