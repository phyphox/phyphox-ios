//
//  RangefilterAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

final class RangefilterAnalysis: ExperimentAnalysisModule {
    private final class Range: CustomStringConvertible {
        let min: Double
        let max: Double
        
        func inBounds(_ value: Double) -> Bool {
            return min <= value && value <= max
        }
        
        init(min: Double, max: Double) {
            self.min = min
            self.max = max
        }
        
        var description: String {
            get {
                return "Range <\(Unmanaged.passUnretained(self).toOpaque())> (\(min), \(max))"
            }
        }
    }
    
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
            }
            else if input.asString == "max" {
                if let v = input.getSingleValue() {
                    currentMax = v
                }
            }
            else {
                switch input {
                case .buffer(buffer: let buffer, usedAs: _, clear: _):
                    if let currentInput = currentIn {
                        iterators.append((Range(min: currentMin, max: currentMax), currentInput))
                    }

                    currentIn = buffer
                    currentMax = Double.infinity
                    currentMin = -Double.infinity
                case .value(value: _, usedAs: _):
                    break
                }
            }
        }
        
        if let currentIn = currentIn {
            iterators.append((Range(min: currentMin, max: currentMax), currentIn))
        }
        
        var delete = Set<Int>()
        
        var out = [[Double]](repeating: [], count: iterators.count)
        
        var deleteCount = 0
        
        #if DEBUG_ANALYSIS
            debug_noteInputs(iterators.map({ (element) -> [Range: DataBuffer] in
                return [element.0 : element.1]
            }))
        #endif
        
        for (index, (range, buffer)) in iterators.enumerated() {
            for (i, value) in buffer.enumerated() {
                if delete.contains(i) {
                    continue
                }
                
                if value.isFinite && !range.inBounds(value) {
                    delete.insert(i)
                    
                    let delIdx = i-deleteCount
                    
                    for j in 0..<index {
                        var ar = out[j]
                        if delIdx >= 0 && delIdx < ar.count {
                            ar.remove(at: delIdx) //Remove values from previous buffers that passed.
                            out[j] = ar
                        }
                    }
                    
                    deleteCount += 1
                    
                    continue
                }
                
                out[index].append(value)
            }
        }
        
        //If values have been missing on one output, we need to fill these with NaN as the results are treated as a group and would not match up if appended subsequently
        var nOut = 0
        for o in out {
            nOut = max(nOut, o.count)
        }
        for i in 0..<out.count {
            while out[i].count < nOut {
                out[i].append(Double.nan)
            }
        }
        
        #if DEBUG_ANALYSIS
            debug_noteOutputs(out)
        #endif
        
        beforeWrite()
        
        for (i, output) in outputs.enumerated() {
            switch output {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(out[i])
                }
                else {
                    buffer.appendFromArray(out[i])
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
    }
}
