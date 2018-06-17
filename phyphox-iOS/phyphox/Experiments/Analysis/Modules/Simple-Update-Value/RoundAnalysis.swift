//
//  RoundAnalysis.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 28.05.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//

import Foundation
import Accelerate

import Foundation
import Accelerate

final class RoundAnalysis: UpdateValueAnalysis {
    private let floor: Bool
    private let ceil: Bool
    
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: XMLElementAttributes<String>) throws {
        floor = try additionalAttributes.optionalAttribute(for: "floor") ?? false
        ceil = try additionalAttributes.optionalAttribute(for: "ceil") ?? false
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
                vvnint(&results, results, [Int32(results.count)])
            }
            
            return results
        }
    }
}
