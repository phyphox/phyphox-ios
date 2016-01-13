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
    }
    
    //TODO: Ich weiß nicht ob es richtig implementiert ist, peile die Dokumentation vom rangefilter nicht
    
    override func update() {
        var iterators: [Range: DataBuffer] = [:]
        
        var currentIn: DataBuffer? = nil
        var currentMax: Double = Double.infinity
        var currentMin: Double = -Double.infinity
        
        for input in inputs {
            if input.asString == "min" {
                currentMin = input.getSingleValue()
            }
            else if input.asString == "max" {
                currentMax = input.getSingleValue()
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
        
        for output in outputs {
            output.buffer!.clear()
        }
        
        for (range, buffer) in iterators {
            var data: [Double?] = []
            
            for value in buffer {
                if !range.inBounds(value) {
                    break //Out of bounds, skip these values
                }
                
                data.append(value)
            }
            
            for v in data {
                for output in outputs {
                    output.buffer!.append(v)
                }
            }
        }
    }
}
