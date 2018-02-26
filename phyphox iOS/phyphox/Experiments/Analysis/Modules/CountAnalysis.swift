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
            let val = input.buffer!.count
            result.append(Double(val))
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
