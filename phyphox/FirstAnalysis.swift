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
        for input in inputs {
            for output in outputs {
                output.buffer!.append(input.buffer!.first)
            }
        }
    }
}
