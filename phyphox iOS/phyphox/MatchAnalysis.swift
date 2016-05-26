//
//  MatchAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 26.05.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class MatchAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        var out = [[Double]](count: inputs.count, repeatedValue: [])

        var allInputs = true
        var i = 0
        while allInputs {
            var allOK = true
            var values = [Double]()
            for input in inputs {
                if let value = input.buffer?.objectAtIndex(i) {
                    if !value.isFinite {
                        allOK = false
                        break
                    } else {
                        values.append(value)
                    }
                } else {
                    allInputs = false
                    break
                }
            }
            i += 1
            if allOK && allInputs {
                for (index, value) in values.enumerate() {
                    out[index].append(value)
                }
            }
        }
        
        for (i, output) in outputs.enumerate() {
            if output.clear {
                output.buffer!.replaceValues(out[i])
            }
            else {
                output.buffer!.appendFromArray(out[i])
            }
        }
    }
}
