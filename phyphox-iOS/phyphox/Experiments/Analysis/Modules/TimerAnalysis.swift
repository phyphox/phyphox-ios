//
//  TimerAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 02.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

final class TimerAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        for output in outputs {
            switch output {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues([timestamp])
                }
                else {
                    buffer.append(timestamp)
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
    }
}
