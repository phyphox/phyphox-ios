//
//  RoundAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 28.05.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//

import Foundation
import Accelerate

final class RoundAnalysis: UpdateValueAnalysis {
    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [
            AnalysisIOSlot(name: "value", asRequired: false, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 1, maxCount: 1)
        ], outputs: [
            AnalysisIOSlot(name: "round", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
        ])
    }
    private let floor: Bool
    private let ceil: Bool
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        let attributes = additionalAttributes.attributes(keyedBy: String.self)

        floor = try attributes.optionalValue(for: "floor") ?? false
        ceil = try attributes.optionalValue(for: "ceil") ?? false
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        updateAllWithMethod { array -> [Double] in
            var results = array

            if floor {
                vvfloor(&results, results, [Int32(results.count)])
            }
            else if ceil {
                vvceil(&results, results, [Int32(results.count)])
            }
            else {
                //Ties round half away from zero (C rounding, like the formula language's
                //round; -0.5 becomes -1) and non-finite values pass through unchanged.
                //vvnint is not usable here: it rounds ties to even (2.5 -> 2).
                results = results.map { $0.rounded(.toNearestOrAwayFromZero) }
            }
            
            return results
        }
    }
}
