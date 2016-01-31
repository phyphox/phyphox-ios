//
//  SubtractionAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class SubtractionAnalysis: ExperimentComplexUpdateValueAnalysis {
    
    override func update() {
        updateWithMethod({ (first, second, initial) -> Double in
            if initial {
                return second
            }
            else {
                return first-second
            }
            }, outerMethod: nil, neutralElement: 0.0, priorityInputKey: "minuend")
    }
}
