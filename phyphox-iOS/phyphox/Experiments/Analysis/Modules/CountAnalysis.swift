//
//  CountAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 06.10.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class CountAnalysis: ExperimentAnalysisModule {
    override func update() {
        var result: [Double] = []
        
        for input in inputs {
            switch input {
            case .buffer(buffer: let buffer, usedAs: _, clear: _):
                let val = buffer.memoryCount
                result.append(Double(val))
            case .value(value: _, usedAs: _):
                result.append(1.0)
            }
        }
        
        beforeWrite()

        for output in outputs {
            switch output {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(result)
                }
                else {
                    buffer.appendFromArray(result)
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
    }
}
