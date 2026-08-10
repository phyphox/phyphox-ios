//
//  MatchAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 26.05.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class MatchAnalysis: AutoClearingExperimentAnalysisModule {
    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [
            AnalysisIOSlot(name: "in", asRequired: false, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 0)
        ], outputs: [
            AnalysisIOSlot(name: "out", asRequired: false, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 0)
        ])
    }
    
    override func update() {
        var out = [[Double]](repeating: [], count: inputs.count)

        var allInputs = true
        var i = 0
        while allInputs {
            var allOK = true
            var values = [Double]()
            for input in inputs {
                switch input {
                case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                    if i < data.data.count {
                        let value = data.data[i]
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
                case .value(value: _, usedAs: _):
                    break
                }
            }
            i += 1
            if allOK && allInputs {
                for (index, value) in values.enumerated() {
                    out[index].append(value)
                }
            }
        }
                
        for (i, output) in outputs.enumerated() {
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(out[i])
            }
        }
    }
}
