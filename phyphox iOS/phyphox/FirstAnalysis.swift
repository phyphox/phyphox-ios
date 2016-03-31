//
//  FirstAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class FirstAnalysis: ExperimentAnalysisModule {

    override func update() {
        var result: [Double] = []
        
        for input in inputs {
            if let val = input.buffer!.first {
                result.append(val)
            }
        }
        
        for output in outputs {
            if output.clear {
                output.buffer!.replaceValues(result)
            }
            else {
                output.buffer!.appendFromArray(result)
            }
        }
    }
}
