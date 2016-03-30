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
        var append: [Double] = []
        
        for input in inputs {
            if let val = input.buffer!.first {
                append.append(val)
            }
        }
        
        for output in outputs {
            output.buffer!.appendFromArray(append)
        }
    }
}
