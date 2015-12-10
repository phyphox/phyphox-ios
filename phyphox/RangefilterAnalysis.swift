//
//  RangefilterAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class RangefilterAnalysis: ExperimentAnalysis {
    //Hold min and max as string as it might be a dataBuffer
    var min: [String?]
    var max: [String?]
    
    init(experiment: Experiment, inputs: [String], outputs: [DataBuffer], min: [String?], max: [String?]) {
        self.min = min
        self.max = max
        super.init(experiment: experiment, inputs: inputs, outputs: outputs)
    }
    
    override func update() {
        var minD = [Double](count: inputs.count, repeatedValue: 0.0)
        var maxD = [Double](count: inputs.count, repeatedValue: 0.0)
        
        for i in 0..<inputs.count {
            if let val = min[i] {
                minD[i] = getSingleValueFromUserString(val)!
            }
            else {
                minD[i] = -Double.infinity
            }
            
            if let val = max[i] {
                maxD[i] = getSingleValueFromUserString(val)!
            }
            else {
                maxD[i] = Double.infinity
            }
        }
        
        var iterators = [IndexingGenerator<Array<Double>>?](count: inputs.count, repeatedValue: nil)
        
        //Get iterators of all inputs (numeric string not allowed here as it makes no sense to filter static input)
        for (i, input) in inputs.enumerate() {
            if fixedValues[i] == nil {
                iterators.append(getBufferForKey(input)!.generate())
            }
        }
        
        for output in outputs {
            output.clear()
        }
        
        var data = [Double?](count: inputs.count, repeatedValue: nil)
        
        while true {
            var filter = false
            var hasNext = false
            for i in 0..<inputs.count {
                if var iterator = iterators[i] {
                    if let next = iterator.next() {
                        data[i] = next
                        hasNext = true
                        
                        if (next < minD[i] || next > maxD[i]) {
                            filter = true
                            break
                        }
                    }
                }
                
                if hasNext && filter { //No more need for the loop, we know that the big loop won't break and that the value has to be filtered.
                    break
                }
            }
            
            if !hasNext {
                break
            }
            
            if !filter {
                for (i, output) in outputs.enumerate() {
                    output.append(data[i])
                }
            }
        }
    }
}
