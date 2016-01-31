//
//  AdditionAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class AdditionAnalysis: ExperimentArithmeticModule {
    
    override func update() {
        updateWithMethod({ (first, second, initial) -> Double in
            return first+second
            }, neutralElement: 0.0, priorityInputKey: nil)
    }
}
