//
//  ABSAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import Accelerate

final class ABSAnalysis: UpdateValueAnalysis {
    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [
            AnalysisIOSlot(name: "value", asRequired: false, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 1, maxCount: 1)
        ], outputs: [
            AnalysisIOSlot(name: "abs", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
        ])
    }
    
    override func update() {
        updateAllWithMethod { array -> [Double] in
            var results = array
            vvfabs(&results, array, [Int32(array.count)])
            
            return results
        }
    }
}
