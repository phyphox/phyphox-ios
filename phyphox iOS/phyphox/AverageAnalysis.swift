//
//  AverageAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 06.10.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class AverageAnalysis: ExperimentAnalysisModule {
    private var avgOutput: ExperimentAnalysisDataIO?
    private var stdOutput: ExperimentAnalysisDataIO?
    
    override init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String : AnyObject]?) throws {
        var avg: ExperimentAnalysisDataIO? = nil
        var std: ExperimentAnalysisDataIO? = nil
        for output in outputs {
            if output.asString == "std" || avg != nil {
                std = output
            }
            else {
                avg = output
            }
        }
        avgOutput = avg
        stdOutput = std
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
     
        if inputs.count == 0 || inputs[0].buffer == nil {
            return
        }
        
        var sum = 0.0
        var count = 0
        for v in inputs[0].buffer! {
            if v.isFinite {
                sum += v
                count += 1
            }
        }
        if count == 0 {
            return
        }

        let avg = sum/Double(count)
        
        if avgOutput != nil {
            if avgOutput!.clear {
                avgOutput!.buffer!.replaceValues([avg])
            }
            else {
                avgOutput!.buffer!.appendFromArray([avg])
            }
        }
        
        if stdOutput != nil {
            let std: Double
            if (count < 2) {
                std = Double.NaN
            } else {
                sum = 0.0
                count = 0
                for v in inputs[0].buffer! {
                    if v.isFinite {
                        sum += (v-avg)*(v-avg)
                        count += 1
                    }
                }
                std = sqrt(sum/(Double(count-1)))
            }
            if stdOutput!.clear {
                stdOutput!.buffer!.replaceValues([std])
            }
            else {
                stdOutput!.buffer!.appendFromArray([std])
            }
        }
        
    }
}
