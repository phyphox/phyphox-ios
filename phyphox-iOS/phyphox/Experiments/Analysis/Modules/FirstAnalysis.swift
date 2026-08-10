//
//  FirstAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

final class FirstAnalysis: AutoClearingExperimentAnalysisModule {
    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [
            AnalysisIOSlot(name: "value", asRequired: false, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 0)
        ], outputs: [
            AnalysisIOSlot(name: "first", asRequired: false, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 0)
        ])
    }
    override func update() {
        var result: [Double] = []
        
        for input in inputs {
            switch input {
            case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                if data.data.count > 0 {
                    result.append(data.data[0])
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
        
        for output in outputs {
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(result)
            }
        }
    }
}
