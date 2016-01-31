//
//  PowerAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class PowerAnalysis: ExperimentArithmeticModule {
    
    override func update() {
        updateWithMethod({ (first, second, initial) -> Double in
            if initial {
                return second
            }
            else {
                return pow(first, second)
            }
            }, neutralElement: 1.0, priorityInputKey: "base")
    }
}
