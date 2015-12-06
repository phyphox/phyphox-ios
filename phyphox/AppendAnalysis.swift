//
//  AppendAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class AppendAnalysis: ExperimentAnalysis {
    override func update() {
        outputs.first!.clear()
        
        for (i, input) in inputs.enumerate() {
            if fixedValues[i] != nil {
                continue
            }
            else {
                for val in getBufferForKey(input)! {
                    outputs.first!.append(val)
                }
            }
        }
    }
}
