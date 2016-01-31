//
//  AdditionAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class AdditionAnalysis: ExperimentComplexUpdateValueAnalysis {
    
    override func update() {
        updateWithMethod({ (first, second, initial) -> Double in
            return first+second
            }, outerMethod: nil, neutralElement: 0.0, priorityInputKey: nil)
    }
}
