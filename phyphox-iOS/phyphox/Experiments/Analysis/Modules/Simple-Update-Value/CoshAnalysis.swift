//
//  CoshAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 06.10.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation
import Accelerate

final class CoshAnalysis: UpdateValueAnalysis {
    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [
            AnalysisIOSlot(name: "value", asRequired: false, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 1, maxCount: 1)
        ], outputs: [
            AnalysisIOSlot(name: "cosh", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
        ])
    }
    
    override func update() {
        updateAllWithMethod { array -> [Double] in
            var results = array
            
            vvcosh(&results, array, [Int32(array.count)])
            
            return results
        }
    }
}
