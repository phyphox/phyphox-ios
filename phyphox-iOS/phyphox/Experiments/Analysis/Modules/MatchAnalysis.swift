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
        var out = [[Double]](repeating: [], count: inputs.count)

        var allInputs = true
        var i = 0
        while allInputs {
            var allOK = true
            var values = [Double]()
            for input in inputs {
                switch input {
                case .buffer(buffer: let buffer, usedAs: _, clear: _):
                    if let value = buffer.objectAtIndex(i) {
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
        
        beforeWrite()
        
        for (i, output) in outputs.enumerated() {
            switch output {
            case .value(value: _, usedAs: _):
                break
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(out[i])
                }
                else {
                    buffer.appendFromArray(out[i])
                }
            }
        }
    }
}
