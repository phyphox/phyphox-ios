//
//  CountAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 06.10.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class CountAnalysis: AutoClearingExperimentAnalysisModule {
    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [
            AnalysisIOSlot(name: "buffer", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
        ], outputs: [
            AnalysisIOSlot(name: "count", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
        ])
    }
    override func update() {
        var result: [Double] = []
        
        for input in inputs {
            switch input {
            case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                let val = data.data.count
                result.append(Double(val))
            case .value(value: _, usedAs: _):
                result.append(1.0)
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
